$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$ProjectRoot = (Get-Location).Path
$RelativePath = "src/main/java/net/droingo/decor/client/animation/BobbleheadMotionState.java"
$Target = Join-Path $ProjectRoot $RelativePath
$BackupRoot = Join-Path $ProjectRoot (".bobble_frame_motion_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
$Backup = Join-Path $BackupRoot $RelativePath

if (!(Test-Path -LiteralPath (Join-Path $ProjectRoot "build.gradle"))) {
    throw "Run this script from the Droingo's Decor project root."
}

if (!(Test-Path -LiteralPath $Target)) {
    throw "Could not find: $Target"
}

New-Item `
    -ItemType Directory `
    -Force `
    -Path (Split-Path -Parent $Backup) | Out-Null

Copy-Item `
    -LiteralPath $Target `
    -Destination $Backup `
    -Force

[System.IO.File]::WriteAllText(
    $Target,
@'
package net.droingo.decor.client.animation;

import net.minecraft.util.Mth;
import net.minecraft.world.phys.Vec3;

import java.util.Arrays;

/**
 * Lightweight client-side bobblehead spring.
 *
 * Motion capture uses a monotonic real-time clock and observes the projected
 * position every rendered frame. Repeated identical projected positions are
 * ignored instead of being recorded as zero-velocity samples.
 *
 * This makes the bobblehead independent from world game-time timing and from
 * the exact point in the tick when Sable publishes a new projected transform.
 */
public final class BobbleheadMotionState {
    private static final float MAX_ANGLE_DEGREES = 38.0F;
    private static final float ACCELERATION_GAIN = 2200.0F;

    private static final float SPRING_STRENGTH = 0.48F;
    private static final float VELOCITY_DAMPING = 0.84F;

    private static final double ACCELERATION_DEAD_ZONE = 0.00175D;

    private static final float SETTLE_ANGLE_DEGREES = 0.08F;
    private static final float SETTLE_VELOCITY = 0.025F;

    private static final double MAX_SAMPLE_SPEED = 8.0D;
    private static final double MAX_SAMPLE_ACCELERATION = 2.5D;

    private static final int VELOCITY_FILTER_SIZE = 5;

    private static final double POSITION_CHANGE_EPSILON_SQR = 1.0E-12D;
    private static final double MAX_SAMPLE_GAP_SECONDS = 0.50D;
    private static final double MAX_RENDER_GAP_SECONDS = 0.25D;

    private boolean initialized;

    private double lastRenderSeconds;
    private double lastMotionSampleSeconds;

    private Vec3 lastObservedPosition = Vec3.ZERO;
    private Vec3 lastFilteredVelocity = Vec3.ZERO;

    private final Vec3[] velocitySamples =
            new Vec3[VELOCITY_FILTER_SIZE];

    private int velocitySampleCount;
    private int velocitySampleIndex;

    private float targetPitchDegrees;
    private float targetRollDegrees;

    private float pitchDegrees;
    private float rollDegrees;

    private float pitchVelocity;
    private float rollVelocity;

    /**
     * The timeline argument is retained so existing renderer calls remain
     * source-compatible. Motion timing now comes from System.nanoTime().
     */
    public void update(
            double ignoredTimelineTime,
            Vec3 worldPosition,
            Vec3 parrotRight,
            Vec3 parrotForward
    ) {
        double nowSeconds =
                System.nanoTime() * 1.0E-9D;

        if (
                !Double.isFinite(nowSeconds)
                        || !isFinite(worldPosition)
        ) {
            return;
        }

        if (!initialized) {
            reset(nowSeconds, worldPosition);
            return;
        }

        double renderDeltaSeconds =
                nowSeconds - lastRenderSeconds;

        /*
         * Protect against long render gaps, pauses and debugger stalls.
         */
        if (
                renderDeltaSeconds <= 0.0D
                        || renderDeltaSeconds > MAX_RENDER_GAP_SECONDS
        ) {
            reset(nowSeconds, worldPosition);
            return;
        }

        Vec3 positionDelta =
                worldPosition.subtract(lastObservedPosition);

        /*
         * Only produce a velocity sample when Sable publishes a genuinely new
         * projected position. Repeated positions are not fake zero movement.
         */
        if (
                positionDelta.lengthSqr()
                        > POSITION_CHANGE_EPSILON_SQR
        ) {
            double sampleDeltaSeconds =
                    nowSeconds - lastMotionSampleSeconds;

            if (
                    sampleDeltaSeconds > 0.0D
                            && sampleDeltaSeconds
                            <= MAX_SAMPLE_GAP_SECONDS
            ) {
                sampleVehicleMotion(
                        worldPosition,
                        parrotRight,
                        parrotForward,
                        sampleDeltaSeconds
                );
            } else {
                clearVelocityFilter();
                lastFilteredVelocity = Vec3.ZERO;
                targetPitchDegrees = 0.0F;
                targetRollDegrees = 0.0F;
            }

            lastObservedPosition = worldPosition;
            lastMotionSampleSeconds = nowSeconds;
        } else {
            /*
             * Let an old input decay naturally if no new projected transform
             * has arrived for a short period.
             */
            double idleSeconds =
                    nowSeconds - lastMotionSampleSeconds;

            if (idleSeconds > 0.15D) {
                targetPitchDegrees *= 0.82F;
                targetRollDegrees *= 0.82F;
            }
        }

        /*
         * Keep spring tuning in Minecraft-tick units so it behaves like the
         * original spring regardless of frame rate.
         */
        float renderDeltaTicks =
                (float) (renderDeltaSeconds * 20.0D);

        integrateSpring(
                Mth.clamp(
                        renderDeltaTicks,
                        0.0F,
                        2.0F
                )
        );

        lastRenderSeconds = nowSeconds;
    }

    private void sampleVehicleMotion(
            Vec3 worldPosition,
            Vec3 parrotRight,
            Vec3 parrotForward,
            double sampleDeltaSeconds
    ) {
        double sampleDeltaTicks =
                sampleDeltaSeconds * 20.0D;

        if (sampleDeltaTicks <= 0.0001D) {
            return;
        }

        Vec3 rawVelocity = worldPosition
                .subtract(lastObservedPosition)
                .scale(1.0D / sampleDeltaTicks);

        /*
         * Treat huge discontinuities as teleports or projection changes rather
         * than physical movement.
         */
        if (
                rawVelocity.lengthSqr()
                        > MAX_SAMPLE_SPEED * MAX_SAMPLE_SPEED
        ) {
            clearVelocityFilter();

            lastFilteredVelocity = Vec3.ZERO;
            targetPitchDegrees = 0.0F;
            targetRollDegrees = 0.0F;
            return;
        }

        addVelocitySample(rawVelocity);

        Vec3 filteredVelocity =
                getFilteredVelocity();

        Vec3 worldAcceleration = filteredVelocity
                .subtract(lastFilteredVelocity)
                .scale(1.0D / sampleDeltaTicks);

        double accelerationLength =
                worldAcceleration.length();

        if (
                accelerationLength
                        < ACCELERATION_DEAD_ZONE
        ) {
            worldAcceleration = Vec3.ZERO;
        } else if (
                accelerationLength
                        > MAX_SAMPLE_ACCELERATION
        ) {
            worldAcceleration =
                    worldAcceleration.scale(
                            MAX_SAMPLE_ACCELERATION
                                    / accelerationLength
                    );
        }

        double rightAcceleration =
                worldAcceleration.dot(parrotRight);

        double forwardAcceleration =
                worldAcceleration.dot(parrotForward);

        if (
                Math.abs(rightAcceleration)
                        < ACCELERATION_DEAD_ZONE
        ) {
            rightAcceleration = 0.0D;
        }

        if (
                Math.abs(forwardAcceleration)
                        < ACCELERATION_DEAD_ZONE
        ) {
            forwardAcceleration = 0.0D;
        }

        targetRollDegrees = Mth.clamp(
                (float) (
                        rightAcceleration
                                * ACCELERATION_GAIN
                ),
                -MAX_ANGLE_DEGREES,
                MAX_ANGLE_DEGREES
        );

        targetPitchDegrees = Mth.clamp(
                (float) (
                        -forwardAcceleration
                                * ACCELERATION_GAIN
                ),
                -MAX_ANGLE_DEGREES,
                MAX_ANGLE_DEGREES
        );

        lastFilteredVelocity = filteredVelocity;
    }

    private void addVelocitySample(Vec3 velocity) {
        velocitySamples[velocitySampleIndex] =
                velocity;

        velocitySampleIndex =
                (velocitySampleIndex + 1)
                        % VELOCITY_FILTER_SIZE;

        if (
                velocitySampleCount
                        < VELOCITY_FILTER_SIZE
        ) {
            velocitySampleCount++;
        }
    }

    private Vec3 getFilteredVelocity() {
        if (velocitySampleCount == 0) {
            return Vec3.ZERO;
        }

        /*
         * Until enough history exists, average the available samples. Once the
         * buffer is full, use the median to reject isolated correction spikes.
         */
        if (
                velocitySampleCount
                        < VELOCITY_FILTER_SIZE
        ) {
            Vec3 total = Vec3.ZERO;

            for (
                    int index = 0;
                    index < velocitySampleCount;
                    index++
            ) {
                total = total.add(
                        velocitySamples[index]
                );
            }

            return total.scale(
                    1.0D / velocitySampleCount
            );
        }

        double[] xValues =
                new double[VELOCITY_FILTER_SIZE];

        double[] yValues =
                new double[VELOCITY_FILTER_SIZE];

        double[] zValues =
                new double[VELOCITY_FILTER_SIZE];

        for (
                int index = 0;
                index < VELOCITY_FILTER_SIZE;
                index++
        ) {
            Vec3 sample =
                    velocitySamples[index];

            xValues[index] = sample.x;
            yValues[index] = sample.y;
            zValues[index] = sample.z;
        }

        Arrays.sort(xValues);
        Arrays.sort(yValues);
        Arrays.sort(zValues);

        int middle =
                VELOCITY_FILTER_SIZE / 2;

        return new Vec3(
                xValues[middle],
                yValues[middle],
                zValues[middle]
        );
    }

    private void clearVelocityFilter() {
        Arrays.fill(
                velocitySamples,
                Vec3.ZERO
        );

        velocitySampleCount = 0;
        velocitySampleIndex = 0;
    }

    private void integrateSpring(float deltaTicks) {
        pitchVelocity +=
                (targetPitchDegrees - pitchDegrees)
                        * SPRING_STRENGTH
                        * deltaTicks;

        rollVelocity +=
                (targetRollDegrees - rollDegrees)
                        * SPRING_STRENGTH
                        * deltaTicks;

        float damping = (float) Math.pow(
                VELOCITY_DAMPING,
                deltaTicks
        );

        pitchVelocity *= damping;
        rollVelocity *= damping;

        pitchDegrees +=
                pitchVelocity * deltaTicks;

        rollDegrees +=
                rollVelocity * deltaTicks;

        applyPitchLimit();
        applyRollLimit();
        settleAtEquilibrium();
    }

    private void settleAtEquilibrium() {
        boolean noMeaningfulInput =
                Math.abs(targetPitchDegrees)
                        < SETTLE_ANGLE_DEGREES
                        && Math.abs(targetRollDegrees)
                        < SETTLE_ANGLE_DEGREES;

        if (!noMeaningfulInput) {
            return;
        }

        if (
                Math.abs(pitchDegrees)
                        < SETTLE_ANGLE_DEGREES
                        && Math.abs(pitchVelocity)
                        < SETTLE_VELOCITY
        ) {
            pitchDegrees = 0.0F;
            pitchVelocity = 0.0F;
        }

        if (
                Math.abs(rollDegrees)
                        < SETTLE_ANGLE_DEGREES
                        && Math.abs(rollVelocity)
                        < SETTLE_VELOCITY
        ) {
            rollDegrees = 0.0F;
            rollVelocity = 0.0F;
        }
    }

    private void applyPitchLimit() {
        if (pitchDegrees > MAX_ANGLE_DEGREES) {
            pitchDegrees = MAX_ANGLE_DEGREES;

            if (pitchVelocity > 0.0F) {
                pitchVelocity *= -0.18F;
            }
        } else if (
                pitchDegrees
                        < -MAX_ANGLE_DEGREES
        ) {
            pitchDegrees = -MAX_ANGLE_DEGREES;

            if (pitchVelocity < 0.0F) {
                pitchVelocity *= -0.18F;
            }
        }
    }

    private void applyRollLimit() {
        if (rollDegrees > MAX_ANGLE_DEGREES) {
            rollDegrees = MAX_ANGLE_DEGREES;

            if (rollVelocity > 0.0F) {
                rollVelocity *= -0.18F;
            }
        } else if (
                rollDegrees
                        < -MAX_ANGLE_DEGREES
        ) {
            rollDegrees = -MAX_ANGLE_DEGREES;

            if (rollVelocity < 0.0F) {
                rollVelocity *= -0.18F;
            }
        }
    }

    private void reset(
            double nowSeconds,
            Vec3 worldPosition
    ) {
        initialized = true;

        lastRenderSeconds = nowSeconds;
        lastMotionSampleSeconds = nowSeconds;

        lastObservedPosition = worldPosition;
        lastFilteredVelocity = Vec3.ZERO;

        clearVelocityFilter();

        targetPitchDegrees = 0.0F;
        targetRollDegrees = 0.0F;

        pitchDegrees = 0.0F;
        rollDegrees = 0.0F;

        pitchVelocity = 0.0F;
        rollVelocity = 0.0F;
    }

    private static boolean isFinite(Vec3 value) {
        return Double.isFinite(value.x)
                && Double.isFinite(value.y)
                && Double.isFinite(value.z);
    }

    public float getPitchDegrees() {
        return pitchDegrees;
    }

    public float getRollDegrees() {
        return rollDegrees;
    }
}

'@,
    $Utf8NoBom
)

Write-Host "Installed frame-based bobblehead motion capture."
Write-Host "Backup: $Backup"
Write-Host ""
Write-Host "Building..."
Write-Host ""

& .\gradlew.bat build

if ($LASTEXITCODE -ne 0) {
    throw "Build failed. Send the compile output. Backup: $Backup"
}

Write-Host ""
Write-Host "Build successful."
Write-Host "Test the bobblehead in the affected world."
