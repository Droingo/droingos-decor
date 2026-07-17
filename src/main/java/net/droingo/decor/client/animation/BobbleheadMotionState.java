package net.droingo.decor.client.animation;

import net.minecraft.util.Mth;
import net.minecraft.world.phys.Vec3;

import java.util.Arrays;

/**
 * Lightweight client-side bobblehead spring.
 *
 * Sable projected positions can occasionally receive small correction jumps.
 * Differentiating those positions directly creates false acceleration impulses.
 *
 * Raw velocity is therefore passed through a five-sample component-wise median
 * filter before acceleration is calculated. Isolated corrections disappear,
 * while sustained acceleration, braking and collisions remain visible.
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

    private boolean initialized;

    private double lastRenderTime;
    private long lastSampleTick;

    private Vec3 lastSamplePosition = Vec3.ZERO;
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

    public void update(
            double timelineTime,
            Vec3 worldPosition,
            Vec3 parrotRight,
            Vec3 parrotForward
    ) {
        long currentTick = (long) Math.floor(timelineTime);

        if (!initialized) {
            reset(timelineTime, currentTick, worldPosition);
            return;
        }

        double renderDeltaTicks = timelineTime - lastRenderTime;

        /*
         * Protect against replay seeking, time reversal and long periods where
         * this decoration was not rendered.
         */
        if (renderDeltaTicks <= 0.0D || renderDeltaTicks > 4.0D) {
            reset(timelineTime, currentTick, worldPosition);
            return;
        }

        /*
         * Sample movement only once per game tick.
         */
        if (currentTick != lastSampleTick) {
            long sampleDeltaTicks = currentTick - lastSampleTick;

            if (sampleDeltaTicks <= 0L || sampleDeltaTicks > 4L) {
                reset(timelineTime, currentTick, worldPosition);
                return;
            }

            sampleVehicleMotion(
                    worldPosition,
                    parrotRight,
                    parrotForward,
                    sampleDeltaTicks
            );

            lastSampleTick = currentTick;
            lastSamplePosition = worldPosition;
        }

        /*
         * Render the spring smoothly every frame.
         */
        integrateSpring((float) renderDeltaTicks);

        lastRenderTime = timelineTime;
    }

    private void sampleVehicleMotion(
            Vec3 worldPosition,
            Vec3 parrotRight,
            Vec3 parrotForward,
            long sampleDeltaTicks
    ) {
        double deltaTicks = sampleDeltaTicks;

        Vec3 rawVelocity = worldPosition
                .subtract(lastSamplePosition)
                .scale(1.0D / deltaTicks);

        /*
         * Treat huge discontinuities as teleports or replay/sublevel projection
         * changes rather than physical movement.
         */
        if (rawVelocity.lengthSqr() > MAX_SAMPLE_SPEED * MAX_SAMPLE_SPEED) {
            clearVelocityFilter();

            lastFilteredVelocity = Vec3.ZERO;
            targetPitchDegrees = 0.0F;
            targetRollDegrees = 0.0F;
            return;
        }

        addVelocitySample(rawVelocity);

        Vec3 filteredVelocity = getFilteredVelocity();

        Vec3 worldAcceleration = filteredVelocity
                .subtract(lastFilteredVelocity)
                .scale(1.0D / deltaTicks);

        double accelerationLength = worldAcceleration.length();

        if (accelerationLength < ACCELERATION_DEAD_ZONE) {
            worldAcceleration = Vec3.ZERO;
        } else if (accelerationLength > MAX_SAMPLE_ACCELERATION) {
            worldAcceleration = worldAcceleration.scale(
                    MAX_SAMPLE_ACCELERATION / accelerationLength
            );
        }

        /*
         * Convert world acceleration into the parrot's own local axes.
         */
        double rightAcceleration =
                worldAcceleration.dot(parrotRight);

        double forwardAcceleration =
                worldAcceleration.dot(parrotForward);

        if (Math.abs(rightAcceleration) < ACCELERATION_DEAD_ZONE) {
            rightAcceleration = 0.0D;
        }

        if (Math.abs(forwardAcceleration) < ACCELERATION_DEAD_ZONE) {
            forwardAcceleration = 0.0D;
        }

        /*
         * Sideways acceleration drives Z-axis roll.
         * Forward acceleration drives X-axis pitch.
         */
        targetRollDegrees = Mth.clamp(
                (float) (rightAcceleration * ACCELERATION_GAIN),
                -MAX_ANGLE_DEGREES,
                MAX_ANGLE_DEGREES
        );

        targetPitchDegrees = Mth.clamp(
                (float) (-forwardAcceleration * ACCELERATION_GAIN),
                -MAX_ANGLE_DEGREES,
                MAX_ANGLE_DEGREES
        );

        lastFilteredVelocity = filteredVelocity;
    }

    private void addVelocitySample(Vec3 velocity) {
        velocitySamples[velocitySampleIndex] = velocity;

        velocitySampleIndex =
                (velocitySampleIndex + 1) % VELOCITY_FILTER_SIZE;

        if (velocitySampleCount < VELOCITY_FILTER_SIZE) {
            velocitySampleCount++;
        }
    }

    private Vec3 getFilteredVelocity() {
        /*
         * Until enough history exists, average the available samples. Once the
         * buffer is full, use the median to reject isolated correction spikes.
         */
        if (velocitySampleCount < VELOCITY_FILTER_SIZE) {
            Vec3 total = Vec3.ZERO;

            for (int i = 0; i < velocitySampleCount; i++) {
                total = total.add(velocitySamples[i]);
            }

            return total.scale(1.0D / velocitySampleCount);
        }

        double[] xValues = new double[VELOCITY_FILTER_SIZE];
        double[] yValues = new double[VELOCITY_FILTER_SIZE];
        double[] zValues = new double[VELOCITY_FILTER_SIZE];

        for (int i = 0; i < VELOCITY_FILTER_SIZE; i++) {
            Vec3 sample = velocitySamples[i];

            xValues[i] = sample.x;
            yValues[i] = sample.y;
            zValues[i] = sample.z;
        }

        Arrays.sort(xValues);
        Arrays.sort(yValues);
        Arrays.sort(zValues);

        int middle = VELOCITY_FILTER_SIZE / 2;

        return new Vec3(
                xValues[middle],
                yValues[middle],
                zValues[middle]
        );
    }

    private void clearVelocityFilter() {
        Arrays.fill(velocitySamples, null);

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

        pitchDegrees += pitchVelocity * deltaTicks;
        rollDegrees += rollVelocity * deltaTicks;

        applyPitchLimit();
        applyRollLimit();
        settleAtEquilibrium();
    }

    private void settleAtEquilibrium() {
        boolean noMeaningfulInput =
                Math.abs(targetPitchDegrees) < SETTLE_ANGLE_DEGREES
                        && Math.abs(targetRollDegrees) < SETTLE_ANGLE_DEGREES;

        if (!noMeaningfulInput) {
            return;
        }

        if (
                Math.abs(pitchDegrees) < SETTLE_ANGLE_DEGREES
                        && Math.abs(pitchVelocity) < SETTLE_VELOCITY
        ) {
            pitchDegrees = 0.0F;
            pitchVelocity = 0.0F;
        }

        if (
                Math.abs(rollDegrees) < SETTLE_ANGLE_DEGREES
                        && Math.abs(rollVelocity) < SETTLE_VELOCITY
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
        } else if (pitchDegrees < -MAX_ANGLE_DEGREES) {
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
        } else if (rollDegrees < -MAX_ANGLE_DEGREES) {
            rollDegrees = -MAX_ANGLE_DEGREES;

            if (rollVelocity < 0.0F) {
                rollVelocity *= -0.18F;
            }
        }
    }

    private void reset(
            double timelineTime,
            long currentTick,
            Vec3 worldPosition
    ) {
        initialized = true;

        lastRenderTime = timelineTime;
        lastSampleTick = currentTick;

        lastSamplePosition = worldPosition;
        lastFilteredVelocity = Vec3.ZERO;

        clearVelocityFilter();

        targetPitchDegrees = 0.0F;
        targetRollDegrees = 0.0F;

        pitchDegrees = 0.0F;
        rollDegrees = 0.0F;

        pitchVelocity = 0.0F;
        rollVelocity = 0.0F;
    }

    public float getPitchDegrees() {
        return pitchDegrees;
    }

    public float getRollDegrees() {
        return rollDegrees;
    }
}