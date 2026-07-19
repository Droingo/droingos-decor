package net.droingo.decor.client.animation;

import net.minecraft.util.Mth;

public final class VineChainMotionState {
    private static final int SEGMENTS = 3;

    private static final float[] SPRING = {
            0.16F,
            0.11F,
            0.075F
    };

    private static final float[] DAMPING = {
            0.90F,
            0.93F,
            0.95F
    };

    private static final float[] TRAIL = {
            0.72F,
            1.00F,
            1.30F
    };

    private static final float[] LIMIT = {
            26.0F,
            38.0F,
            50.0F
    };

    private final float[] pitch =
            new float[SEGMENTS];

    private final float[] roll =
            new float[SEGMENTS];

    private final float[] pitchVelocity =
            new float[SEGMENTS];

    private final float[] rollVelocity =
            new float[SEGMENTS];

    private final float[] previousPitchVelocity =
            new float[SEGMENTS];

    private final float[] previousRollVelocity =
            new float[SEGMENTS];

    private float previousRootPitch;
    private float previousRootRoll;

    public void update(
            float rootPitch,
            float rootRoll,
            float deltaTicks
    ) {
        deltaTicks = Mth.clamp(
                deltaTicks,
                0.0F,
                2.0F
        );

        float rootPitchMovement =
                rootPitch - previousRootPitch;

        float rootRollMovement =
                rootRoll - previousRootRoll;

        for (int index = 0; index < SEGMENTS; index++) {
            float parentPitchMovement =
                    index == 0
                            ? rootPitchMovement
                            : previousPitchVelocity[index - 1]
                            * deltaTicks;

            float parentRollMovement =
                    index == 0
                            ? rootRollMovement
                            : previousRollVelocity[index - 1]
                            * deltaTicks;

            float targetPitch =
                    parentPitchMovement
                            * TRAIL[index]
                            * 12.0F;

            float targetRoll =
                    parentRollMovement
                            * TRAIL[index]
                            * 12.0F;

            pitchVelocity[index] +=
                    (targetPitch - pitch[index])
                            * SPRING[index]
                            * deltaTicks;

            rollVelocity[index] +=
                    (targetRoll - roll[index])
                            * SPRING[index]
                            * deltaTicks;

            float damping =
                    (float) Math.pow(
                            DAMPING[index],
                            deltaTicks
                    );

            pitchVelocity[index] *= damping;
            rollVelocity[index] *= damping;

            pitch[index] +=
                    pitchVelocity[index]
                            * deltaTicks;

            roll[index] +=
                    rollVelocity[index]
                            * deltaTicks;

            pitch[index] = Mth.clamp(
                    pitch[index],
                    -LIMIT[index],
                    LIMIT[index]
            );

            roll[index] = Mth.clamp(
                    roll[index],
                    -LIMIT[index],
                    LIMIT[index]
            );
        }

        for (int index = 0; index < SEGMENTS; index++) {
            previousPitchVelocity[index] =
                    pitchVelocity[index];

            previousRollVelocity[index] =
                    rollVelocity[index];
        }

        previousRootPitch = rootPitch;
        previousRootRoll = rootRoll;
    }

    public float getPitch(int segment) {
        return pitch[segment];
    }

    public float getRoll(int segment) {
        return roll[segment];
    }
}