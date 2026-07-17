package net.droingo.decor.client.animation;

import net.minecraft.util.Mth;
import net.minecraft.world.phys.Vec3;

import java.util.Arrays;

/**
 * Client-side weighted pendulum for gravity-reactive wall decorations.
 *
 * Motion capture is deliberately independent from world game time. Projected
 * positions are observed every rendered frame, but velocity is only updated
 * when Sable supplies a genuinely new projected position. This avoids worlds
 * where transform updates arrive after the ordinary game-tick sample point.
 */
public final class HangingGravityMotionState {
    private static final float MAX_AWAY_ANGLE = 80.0F;

    private static final float GRAVITY_STRENGTH = 0.20F;
    private static final float VELOCITY_DAMPING = 0.88F;
    private static final float MAX_ANGULAR_SPEED = 12.0F;

    private static final double INERTIA_STRENGTH = 3.2D;

    private static final double ACCELERATION_DEAD_ZONE = 0.00175D;
    private static final double MAX_SAMPLE_SPEED = 8.0D;
    private static final double MAX_SAMPLE_ACCELERATION = 1.5D;

    private static final int VELOCITY_FILTER_SIZE = 5;

    private static final double POSITION_CHANGE_EPSILON_SQR = 1.0E-12D;
    private static final double MAX_SAMPLE_GAP_SECONDS = 0.50D;
    private static final double MAX_RENDER_GAP_SECONDS = 0.25D;

    private static final float SETTLE_ANGLE = 0.03F;
    private static final float SETTLE_VELOCITY = 0.015F;

    private boolean initialized;

    private double lastRenderSeconds;
    private double lastMotionSampleSeconds;

    private Vec3 lastObservedPosition = Vec3.ZERO;
    private Vec3 lastFilteredVelocity = Vec3.ZERO;
    private Vec3 filteredAcceleration = Vec3.ZERO;

    private final Vec3[] velocitySamples =
            new Vec3[VELOCITY_FILTER_SIZE];

    private int velocitySampleCount;
    private int velocitySampleIndex;

    private float targetSideAngle;
    private float targetAwayAngle;

    private float sideAngle;
    private float awayAngle;

    private float sideVelocity;
    private float awayVelocity;

    public void update(
            double monotonicSeconds,
            Vec3 worldPosition,
            Vec3 decorRight,
            Vec3 decorUp,
            Vec3 awayFromWall
    ) {
        if (
                !isFinite(worldPosition)
                        || !Double.isFinite(monotonicSeconds)
        ) {
            return;
        }

        if (!initialized) {
            reset(monotonicSeconds, worldPosition);

            updateTargets(
                    decorRight,
                    decorUp,
                    awayFromWall
            );

            sideAngle = targetSideAngle;
            awayAngle = targetAwayAngle;
            return;
        }

        double renderDeltaSeconds =
                monotonicSeconds - lastRenderSeconds;

        if (
                renderDeltaSeconds <= 0.0D
                        || renderDeltaSeconds
                        > MAX_RENDER_GAP_SECONDS
        ) {
            reset(monotonicSeconds, worldPosition);

            updateTargets(
                    decorRight,
                    decorUp,
                    awayFromWall
            );

            sideAngle = targetSideAngle;
            awayAngle = targetAwayAngle;
            return;
        }

        Vec3 positionDelta =
                worldPosition.subtract(lastObservedPosition);

        /*
         * Do not feed repeated positions into the velocity filter.
         *
         * Some Sable worlds expose the same projected transform for several
         * frames and then publish the next transform later in the tick. The
         * old once-per-game-tick sampler could therefore see only zeros.
         */
        if (
                positionDelta.lengthSqr()
                        > POSITION_CHANGE_EPSILON_SQR
        ) {
            double sampleDeltaSeconds =
                    monotonicSeconds
                            - lastMotionSampleSeconds;

            if (
                    sampleDeltaSeconds > 0.0D
                            && sampleDeltaSeconds
                            <= MAX_SAMPLE_GAP_SECONDS
            ) {
                sampleVehicleMotion(
                        worldPosition,
                        sampleDeltaSeconds
                );
            } else {
                clearVelocityFilter();
                lastFilteredVelocity = Vec3.ZERO;
                filteredAcceleration = Vec3.ZERO;
            }

            lastObservedPosition = worldPosition;
            lastMotionSampleSeconds = monotonicSeconds;
        } else {
            /*
             * Acceleration is an impulse-like quantity. Let it fade between
             * transform publications rather than replacing it with artificial
             * zero-velocity samples every frame.
             */
            double renderDeltaTicks =
                    renderDeltaSeconds * 20.0D;

            filteredAcceleration =
                    filteredAcceleration.scale(
                            Math.pow(0.72D, renderDeltaTicks)
                    );
        }

        updateTargets(
                decorRight,
                decorUp,
                awayFromWall
        );

        integrate(
                (float) (renderDeltaSeconds * 20.0D)
        );

        lastRenderSeconds = monotonicSeconds;
    }

    private void sampleVehicleMotion(
            Vec3 worldPosition,
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

        if (
                rawVelocity.lengthSqr()
                        > MAX_SAMPLE_SPEED * MAX_SAMPLE_SPEED
        ) {
            clearVelocityFilter();
            lastFilteredVelocity = Vec3.ZERO;
            filteredAcceleration = Vec3.ZERO;
            return;
        }

        addVelocitySample(rawVelocity);

        Vec3 filteredVelocity =
                getFilteredVelocity();

        Vec3 acceleration = filteredVelocity
                .subtract(lastFilteredVelocity)
                .scale(1.0D / sampleDeltaTicks);

        double accelerationLength =
                acceleration.length();

        if (
                accelerationLength
                        < ACCELERATION_DEAD_ZONE
        ) {
            acceleration = Vec3.ZERO;
        } else if (
                accelerationLength
                        > MAX_SAMPLE_ACCELERATION
        ) {
            acceleration = acceleration.scale(
                    MAX_SAMPLE_ACCELERATION
                            / accelerationLength
            );
        }

        filteredAcceleration = acceleration;
        lastFilteredVelocity = filteredVelocity;
    }

    private void updateTargets(
            Vec3 decorRight,
            Vec3 decorUp,
            Vec3 awayFromWall
    ) {
        Vec3 worldGravity =
                new Vec3(0.0D, -1.0D, 0.0D);

        Vec3 effectiveGravity = worldGravity.subtract(
                filteredAcceleration.scale(
                        INERTIA_STRENGTH
                )
        );

        if (effectiveGravity.lengthSqr() < 0.000001D) {
            effectiveGravity = worldGravity;
        } else {
            effectiveGravity =
                    effectiveGravity.normalize();
        }

        double localDownComponent =
                effectiveGravity.dot(
                        decorUp.scale(-1.0D)
                );

        double sideComponent =
                effectiveGravity.dot(decorRight);

        double awayComponent = Math.max(
                0.0D,
                effectiveGravity.dot(awayFromWall)
        );

        targetSideAngle = Mth.wrapDegrees(
                (float) Math.toDegrees(
                        Math.atan2(
                                sideComponent,
                                localDownComponent
                        )
                )
        );

        double verticalMagnitude = Math.sqrt(
                sideComponent * sideComponent
                        + localDownComponent
                        * localDownComponent
        );

        targetAwayAngle = Mth.clamp(
                (float) Math.toDegrees(
                        Math.atan2(
                                awayComponent,
                                Math.max(
                                        0.0001D,
                                        verticalMagnitude
                                )
                        )
                ),
                0.0F,
                MAX_AWAY_ANGLE
        );
    }

    private void integrate(float deltaTicks) {
        deltaTicks = Mth.clamp(
                deltaTicks,
                0.0F,
                2.0F
        );

        float sideDifference = Mth.wrapDegrees(
                targetSideAngle - sideAngle
        );

        float awayDifference =
                targetAwayAngle - awayAngle;

        sideVelocity +=
                sideDifference
                        * GRAVITY_STRENGTH
                        * deltaTicks;

        awayVelocity +=
                awayDifference
                        * GRAVITY_STRENGTH
                        * deltaTicks;

        float damping = (float) Math.pow(
                VELOCITY_DAMPING,
                deltaTicks
        );

        sideVelocity *= damping;
        awayVelocity *= damping;

        sideVelocity = Mth.clamp(
                sideVelocity,
                -MAX_ANGULAR_SPEED,
                MAX_ANGULAR_SPEED
        );

        awayVelocity = Mth.clamp(
                awayVelocity,
                -MAX_ANGULAR_SPEED,
                MAX_ANGULAR_SPEED
        );

        sideAngle = Mth.wrapDegrees(
                sideAngle
                        + sideVelocity
                        * deltaTicks
        );

        awayAngle +=
                awayVelocity * deltaTicks;

        applyWallLimit();
        settleAtEquilibrium();
    }

    private void applyWallLimit() {
        if (awayAngle < 0.0F) {
            awayAngle = 0.0F;

            if (awayVelocity < 0.0F) {
                awayVelocity *= -0.12F;
            }
        } else if (awayAngle > MAX_AWAY_ANGLE) {
            awayAngle = MAX_AWAY_ANGLE;

            if (awayVelocity > 0.0F) {
                awayVelocity *= -0.15F;
            }
        }
    }

    private void settleAtEquilibrium() {
        float sideDifference = Mth.wrapDegrees(
                targetSideAngle - sideAngle
        );

        if (
                Math.abs(sideDifference) < SETTLE_ANGLE
                        && Math.abs(sideVelocity)
                        < SETTLE_VELOCITY
        ) {
            sideAngle = targetSideAngle;
            sideVelocity = 0.0F;
        }

        if (
                Math.abs(targetAwayAngle - awayAngle)
                        < SETTLE_ANGLE
                        && Math.abs(awayVelocity)
                        < SETTLE_VELOCITY
        ) {
            awayAngle = targetAwayAngle;
            awayVelocity = 0.0F;
        }
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

    private void reset(
            double monotonicSeconds,
            Vec3 worldPosition
    ) {
        initialized = true;

        lastRenderSeconds = monotonicSeconds;
        lastMotionSampleSeconds = monotonicSeconds;

        lastObservedPosition = worldPosition;
        lastFilteredVelocity = Vec3.ZERO;
        filteredAcceleration = Vec3.ZERO;

        clearVelocityFilter();

        sideVelocity = 0.0F;
        awayVelocity = 0.0F;
    }

    private static boolean isFinite(Vec3 value) {
        return Double.isFinite(value.x)
                && Double.isFinite(value.y)
                && Double.isFinite(value.z);
    }

    public float getSideAngle() {
        return sideAngle;
    }

    public float getAwayAngle() {
        return awayAngle;
    }
}
