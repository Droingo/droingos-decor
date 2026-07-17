package net.droingo.decor.client.animation;

import net.minecraft.util.Mth;
import net.minecraft.world.phys.Vec3;

import java.util.Arrays;

/**
 * Client-side weighted pendulum for gravity-reactive wall decorations.
 *
 * The resting direction is based on world gravity. Changes in the projected
 * sublevel velocity add an inertial force, making the hanging object swing
 * during acceleration, braking, impacts and turns.
 */
public final class HangingGravityMotionState {
    private static final float MAX_AWAY_ANGLE = 80.0F;

    private static final float GRAVITY_STRENGTH = 0.20F;
    private static final float VELOCITY_DAMPING = 0.88F;
    private static final float MAX_ANGULAR_SPEED = 12.0F;

    /*
     * How strongly vehicle acceleration affects the apparent gravity vector.
     *
     * Raise this for more crash/acceleration swing.
     * Lower it if ordinary driving moves the sweater too much.
     */
    private static final double INERTIA_STRENGTH = 3.2D;

    private static final double ACCELERATION_DEAD_ZONE = 0.00175D;
    private static final double MAX_SAMPLE_SPEED = 8.0D;
    private static final double MAX_SAMPLE_ACCELERATION = 1.5D;

    private static final int VELOCITY_FILTER_SIZE = 5;

    private static final float SETTLE_ANGLE = 0.03F;
    private static final float SETTLE_VELOCITY = 0.015F;

    private boolean initialized;

    private double lastRenderTime;
    private long lastSampleTick;

    private Vec3 lastSamplePosition = Vec3.ZERO;
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
            double timelineTime,
            Vec3 worldPosition,
            Vec3 decorRight,
            Vec3 decorUp,
            Vec3 awayFromWall
    ) {
        long currentTick = (long) Math.floor(timelineTime);

        if (!initialized) {
            reset(
                    timelineTime,
                    currentTick,
                    worldPosition
            );

            updateTargets(
                    decorRight,
                    decorUp,
                    awayFromWall
            );

            sideAngle = targetSideAngle;
            awayAngle = targetAwayAngle;
            return;
        }

        double renderDeltaTicks =
                timelineTime - lastRenderTime;

        /*
         * Protect against replay seeking, time reversal and long rendering
         * gaps. These should reset rather than create huge false impulses.
         */
        if (
                renderDeltaTicks <= 0.0D
                        || renderDeltaTicks > 4.0D
        ) {
            reset(
                    timelineTime,
                    currentTick,
                    worldPosition
            );

            updateTargets(
                    decorRight,
                    decorUp,
                    awayFromWall
            );

            sideAngle = targetSideAngle;
            awayAngle = targetAwayAngle;
            return;
        }

        /*
         * Sample sublevel movement only once per game tick. Render frames
         * inside the same tick cannot overwrite the meaningful velocity.
         */
        if (currentTick != lastSampleTick) {
            long sampleDeltaTicks =
                    currentTick - lastSampleTick;

            if (
                    sampleDeltaTicks <= 0L
                            || sampleDeltaTicks > 4L
            ) {
                reset(
                        timelineTime,
                        currentTick,
                        worldPosition
                );
            } else {
                sampleVehicleMotion(
                        worldPosition,
                        sampleDeltaTicks
                );

                lastSampleTick = currentTick;
                lastSamplePosition = worldPosition;
            }
        }

        updateTargets(
                decorRight,
                decorUp,
                awayFromWall
        );

        integrate((float) renderDeltaTicks);

        lastRenderTime = timelineTime;
    }

    private void sampleVehicleMotion(
            Vec3 worldPosition,
            long sampleDeltaTicks
    ) {
        double deltaTicks = sampleDeltaTicks;

        Vec3 rawVelocity = worldPosition
                .subtract(lastSamplePosition)
                .scale(1.0D / deltaTicks);

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
                .scale(1.0D / deltaTicks);

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

        /*
         * A hanging object responds opposite the vehicle's acceleration.
         *
         * During a sudden stop, acceleration points backward, so subtracting
         * it tilts effective gravity forward and the sweater continues in the
         * direction the vehicle had been travelling.
         */
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

        /*
         * Movement through the wall remains prohibited. Only effective force
         * pulling the sweater outward contributes to this axis.
         */
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
                null
        );

        velocitySampleCount = 0;
        velocitySampleIndex = 0;
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
        filteredAcceleration = Vec3.ZERO;

        clearVelocityFilter();

        targetSideAngle = 0.0F;
        targetAwayAngle = 0.0F;

        sideVelocity = 0.0F;
        awayVelocity = 0.0F;
    }

    public float getSideAngle() {
        return sideAngle;
    }

    public float getAwayAngle() {
        return awayAngle;
    }
}