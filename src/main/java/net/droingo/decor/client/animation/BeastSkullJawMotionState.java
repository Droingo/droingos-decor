package net.droingo.decor.client.animation;

import net.minecraft.util.Mth;
import net.minecraft.world.phys.Vec3;

import java.util.Arrays;

public final class BeastSkullJawMotionState {
    private static final float MAX_ANGLE = 18.0F;
    private static final float SPRING = 0.18F;
    private static final float DAMPING = 0.90F;
    private static final float MAX_SPEED = 5.0F;

    private static final double INERTIA = 140.0D;
    private static final double DEAD_ZONE = 0.0015D;
    private static final double MAX_SAMPLE_SPEED = 8.0D;
    private static final double MAX_ACCELERATION = 1.25D;

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

    private final Vec3[] velocitySamples = new Vec3[FILTER_SIZE];
    private int sampleCount;
    private int sampleIndex;

    private float targetAngle;
    private float angle;
    private float angularVelocity;

    public void update(
            double seconds,
            Vec3 worldPosition,
            Vec3 localForward
    ) {
        if (!Double.isFinite(seconds) || !finite(worldPosition)) {
            return;
        }

        if (!initialized) {
            reset(seconds, worldPosition);
            return;
        }

        double frameSeconds = seconds - lastRenderSeconds;

        if (frameSeconds <= 0.0D || frameSeconds > MAX_RENDER_GAP_SECONDS) {
            reset(seconds, worldPosition);
            return;
        }

        Vec3 delta = worldPosition.subtract(lastPosition);

        if (delta.lengthSqr() > POSITION_EPSILON_SQR) {
            double sampleSeconds = seconds - lastMotionSampleSeconds;

            if (sampleSeconds > 0.0D && sampleSeconds <= MAX_SAMPLE_GAP_SECONDS) {
                sampleMotion(worldPosition, sampleSeconds);
            } else {
                clearFilter();
                lastFilteredVelocity = Vec3.ZERO;
                acceleration = Vec3.ZERO;
            }

            lastPosition = worldPosition;
            lastMotionSampleSeconds = seconds;
        } else {
            acceleration = acceleration.scale(
                    Math.pow(0.72D, frameSeconds * 20.0D)
            );
        }

        Vec3 forward = localForward.lengthSqr() < 0.000001D
                ? new Vec3(0.0D, 0.0D, 1.0D)
                : localForward.normalize();

        targetAngle = Mth.clamp(
                (float) (acceleration.dot(forward) * INERTIA),
                -MAX_ANGLE,
                MAX_ANGLE
        );

        integrate((float) (frameSeconds * 20.0D));
        lastRenderSeconds = seconds;
    }

    private void sampleMotion(
            Vec3 worldPosition,
            double sampleSeconds
    ) {
        double sampleTicks = sampleSeconds * 20.0D;

        if (sampleTicks <= 0.0001D) {
            return;
        }

        Vec3 velocity = worldPosition
                .subtract(lastPosition)
                .scale(1.0D / sampleTicks);

        if (velocity.lengthSqr() > MAX_SAMPLE_SPEED * MAX_SAMPLE_SPEED) {
            clearFilter();
            lastFilteredVelocity = Vec3.ZERO;
            acceleration = Vec3.ZERO;
            return;
        }

        addSample(velocity);

        Vec3 filtered = filteredVelocity();

        Vec3 newAcceleration = filtered
                .subtract(lastFilteredVelocity)
                .scale(1.0D / sampleTicks);

        double length = newAcceleration.length();

        if (length < DEAD_ZONE) {
            newAcceleration = Vec3.ZERO;
        } else if (length > MAX_ACCELERATION) {
            newAcceleration = newAcceleration.scale(MAX_ACCELERATION / length);
        }

        acceleration = newAcceleration;
        lastFilteredVelocity = filtered;
    }

    private void integrate(float ticks) {
        ticks = Mth.clamp(ticks, 0.0F, 2.0F);

        angularVelocity +=
                (targetAngle - angle)
                        * SPRING
                        * ticks;

        angularVelocity *= (float) Math.pow(DAMPING, ticks);
        angularVelocity = Mth.clamp(
                angularVelocity,
                -MAX_SPEED,
                MAX_SPEED
        );

        angle += angularVelocity * ticks;
        angle = Mth.clamp(angle, -MAX_ANGLE, MAX_ANGLE);
    }

    private void addSample(Vec3 velocity) {
        velocitySamples[sampleIndex] = velocity;
        sampleIndex = (sampleIndex + 1) % FILTER_SIZE;

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

            for (int i = 0; i < sampleCount; i++) {
                total = total.add(velocitySamples[i]);
            }

            return total.scale(1.0D / sampleCount);
        }

        double[] x = new double[FILTER_SIZE];
        double[] y = new double[FILTER_SIZE];
        double[] z = new double[FILTER_SIZE];

        for (int i = 0; i < FILTER_SIZE; i++) {
            Vec3 sample = velocitySamples[i];
            x[i] = sample.x;
            y[i] = sample.y;
            z[i] = sample.z;
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
        Arrays.fill(velocitySamples, Vec3.ZERO);
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
        targetAngle = 0.0F;
        angularVelocity = 0.0F;
        clearFilter();
    }

    private static boolean finite(Vec3 value) {
        return Double.isFinite(value.x)
                && Double.isFinite(value.y)
                && Double.isFinite(value.z);
    }

    public float getAngle() {
        return angle;
    }
}