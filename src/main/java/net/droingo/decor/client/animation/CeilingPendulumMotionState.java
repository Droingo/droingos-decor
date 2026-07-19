package net.droingo.decor.client.animation;

import net.minecraft.util.Mth;
import net.minecraft.world.phys.Vec3;

import java.util.Arrays;

public final class CeilingPendulumMotionState {
    private static final float MAX_ANGLE = 78.0F;
    private static final float SPRING = 0.20F;
    private static final float DAMPING = 0.88F;
    private static final float MAX_SPEED = 12.0F;

    private static final double INERTIA = 3.2D;
    private static final double DEAD_ZONE = 0.00175D;
    private static final double MAX_SAMPLE_SPEED = 8.0D;
    private static final double MAX_ACCELERATION = 1.5D;

    private static final int FILTER_SIZE = 5;
    private static final double POSITION_EPSILON_SQR = 1.0E-12D;
    private static final double MAX_SAMPLE_GAP_SECONDS = 0.50D;
    private static final double MAX_RENDER_GAP_SECONDS = 0.25D;

    private boolean initialized;

    private double lastRenderSeconds;
    private double lastMotionSampleSeconds;

    private Vec3 lastPosition = Vec3.ZERO;
    private Vec3 lastFilteredVelocity = Vec3.ZERO;
    private Vec3 acceleration = Vec3.ZERO;

    private final Vec3[] velocitySamples =
            new Vec3[FILTER_SIZE];

    private int sampleCount;
    private int sampleIndex;

    private float targetPitch;
    private float targetRoll;

    private float pitch;
    private float roll;

    private float pitchVelocity;
    private float rollVelocity;

    public void update(
            double seconds,
            Vec3 worldPosition,
            Vec3 localRight,
            Vec3 localUp,
            Vec3 localForward
    ) {
        if (
                !Double.isFinite(seconds)
                        || !finite(worldPosition)
        ) {
            return;
        }

        if (!initialized) {
            reset(seconds, worldPosition);
            updateTargets(
                    localRight,
                    localUp,
                    localForward
            );
            pitch = targetPitch;
            roll = targetRoll;
            return;
        }

        double frameSeconds =
                seconds - lastRenderSeconds;

        if (
                frameSeconds <= 0.0D
                        || frameSeconds
                        > MAX_RENDER_GAP_SECONDS
        ) {
            reset(seconds, worldPosition);
            updateTargets(
                    localRight,
                    localUp,
                    localForward
            );
            pitch = targetPitch;
            roll = targetRoll;
            return;
        }

        Vec3 delta =
                worldPosition.subtract(lastPosition);

        if (
                delta.lengthSqr()
                        > POSITION_EPSILON_SQR
        ) {
            double sampleSeconds =
                    seconds - lastMotionSampleSeconds;

            if (
                    sampleSeconds > 0.0D
                            && sampleSeconds
                            <= MAX_SAMPLE_GAP_SECONDS
            ) {
                sampleMotion(
                        worldPosition,
                        sampleSeconds
                );
            } else {
                clearFilter();
                lastFilteredVelocity = Vec3.ZERO;
                acceleration = Vec3.ZERO;
            }

            lastPosition = worldPosition;
            lastMotionSampleSeconds = seconds;
        } else {
            acceleration = acceleration.scale(
                    Math.pow(
                            0.72D,
                            frameSeconds * 20.0D
                    )
            );
        }

        updateTargets(
                localRight,
                localUp,
                localForward
        );

        integrate(
                (float) (frameSeconds * 20.0D)
        );

        lastRenderSeconds = seconds;
    }

    private void sampleMotion(
            Vec3 worldPosition,
            double sampleSeconds
    ) {
        double sampleTicks =
                sampleSeconds * 20.0D;

        if (sampleTicks <= 0.0001D) {
            return;
        }

        Vec3 velocity = worldPosition
                .subtract(lastPosition)
                .scale(1.0D / sampleTicks);

        if (
                velocity.lengthSqr()
                        > MAX_SAMPLE_SPEED
                        * MAX_SAMPLE_SPEED
        ) {
            clearFilter();
            lastFilteredVelocity = Vec3.ZERO;
            acceleration = Vec3.ZERO;
            return;
        }

        addSample(velocity);

        Vec3 filtered =
                filteredVelocity();

        Vec3 newAcceleration = filtered
                .subtract(lastFilteredVelocity)
                .scale(1.0D / sampleTicks);

        double length =
                newAcceleration.length();

        if (length < DEAD_ZONE) {
            newAcceleration = Vec3.ZERO;
        } else if (length > MAX_ACCELERATION) {
            newAcceleration =
                    newAcceleration.scale(
                            MAX_ACCELERATION / length
                    );
        }

        acceleration = newAcceleration;
        lastFilteredVelocity = filtered;
    }

    private void updateTargets(
            Vec3 localRight,
            Vec3 localUp,
            Vec3 localForward
    ) {
        /*
         * Gravity minus vehicle acceleration gives the apparent down
         * direction seen by a freely hanging object.
         */
        Vec3 apparentDown =
                new Vec3(0.0D, -1.0D, 0.0D)
                        .subtract(
                                acceleration.scale(INERTIA)
                        );

        if (
                apparentDown.lengthSqr()
                        < 0.000001D
        ) {
            apparentDown =
                    new Vec3(0.0D, -1.0D, 0.0D);
        } else {
            apparentDown = apparentDown.normalize();
        }

        double down =
                apparentDown.dot(
                        localUp.scale(-1.0D)
                );

        double right =
                apparentDown.dot(localRight);

        double forward =
                apparentDown.dot(localForward);

        targetPitch = Mth.clamp(
                (float) Math.toDegrees(
                        Math.atan2(
                                -forward,
                                down
                        )
                ),
                -MAX_ANGLE,
                MAX_ANGLE
        );

        targetRoll = Mth.clamp(
                (float) Math.toDegrees(
                        Math.atan2(
                                right,
                                down
                        )
                ),
                -MAX_ANGLE,
                MAX_ANGLE
        );
    }

    private void integrate(float ticks) {
        ticks = Mth.clamp(ticks, 0.0F, 2.0F);

        pitchVelocity +=
                (targetPitch - pitch)
                        * SPRING
                        * ticks;

        rollVelocity +=
                (targetRoll - roll)
                        * SPRING
                        * ticks;

        float damping =
                (float) Math.pow(DAMPING, ticks);

        pitchVelocity *= damping;
        rollVelocity *= damping;

        pitchVelocity = Mth.clamp(
                pitchVelocity,
                -MAX_SPEED,
                MAX_SPEED
        );

        rollVelocity = Mth.clamp(
                rollVelocity,
                -MAX_SPEED,
                MAX_SPEED
        );

        pitch += pitchVelocity * ticks;
        roll += rollVelocity * ticks;

        pitch = Mth.clamp(
                pitch,
                -MAX_ANGLE,
                MAX_ANGLE
        );

        roll = Mth.clamp(
                roll,
                -MAX_ANGLE,
                MAX_ANGLE
        );
    }

    private void addSample(Vec3 velocity) {
        velocitySamples[sampleIndex] = velocity;

        sampleIndex =
                (sampleIndex + 1) % FILTER_SIZE;

        if (sampleCount < FILTER_SIZE) {
            sampleCount++;
        }
    }

    private Vec3 filteredVelocity() {
        if (sampleCount == 0) {
            return Vec3.ZERO;
        }

        if (sampleCount < FILTER_SIZE) {
            Vec3 total = Vec3.ZERO;

            for (
                    int index = 0;
                    index < sampleCount;
                    index++
            ) {
                total = total.add(
                        velocitySamples[index]
                );
            }

            return total.scale(
                    1.0D / sampleCount
            );
        }

        double[] x = new double[FILTER_SIZE];
        double[] y = new double[FILTER_SIZE];
        double[] z = new double[FILTER_SIZE];

        for (
                int index = 0;
                index < FILTER_SIZE;
                index++
        ) {
            Vec3 sample =
                    velocitySamples[index];

            x[index] = sample.x;
            y[index] = sample.y;
            z[index] = sample.z;
        }

        Arrays.sort(x);
        Arrays.sort(y);
        Arrays.sort(z);

        int middle = FILTER_SIZE / 2;

        return new Vec3(
                x[middle],
                y[middle],
                z[middle]
        );
    }

    private void clearFilter() {
        Arrays.fill(
                velocitySamples,
                Vec3.ZERO
        );

        sampleCount = 0;
        sampleIndex = 0;
    }

    private void reset(
            double seconds,
            Vec3 worldPosition
    ) {
        initialized = true;
        lastRenderSeconds = seconds;
        lastMotionSampleSeconds = seconds;
        lastPosition = worldPosition;
        lastFilteredVelocity = Vec3.ZERO;
        acceleration = Vec3.ZERO;
        clearFilter();
        pitchVelocity = 0.0F;
        rollVelocity = 0.0F;
    }

    private static boolean finite(Vec3 value) {
        return Double.isFinite(value.x)
                && Double.isFinite(value.y)
                && Double.isFinite(value.z);
    }

    public float getPitch() {
        return pitch;
    }

    public float getRoll() {
        return roll;
    }
}