package net.droingo.decor.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import dev.ryanhcode.sable.Sable;
import net.droingo.decor.DroingosDecor;
import net.droingo.decor.client.animation.BeastSkullJawMotionState;
import net.droingo.decor.content.BeastSkullBlock;
import net.droingo.decor.content.BeastSkullBlockEntity;
import net.droingo.decor.content.BeastSkullPlacement;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.block.BlockRenderDispatcher;
import net.minecraft.client.renderer.blockentity.BlockEntityRenderer;
import net.minecraft.client.renderer.blockentity.BlockEntityRendererProvider;
import net.minecraft.client.resources.model.BakedModel;
import net.minecraft.client.resources.model.ModelResourceLocation;
import net.minecraft.core.Direction;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.phys.Vec3;
import net.neoforged.neoforge.client.model.data.ModelData;

import java.util.Map;
import java.util.WeakHashMap;

public final class BeastSkullRenderer
        implements BlockEntityRenderer<BeastSkullBlockEntity> {

    private final Map<
            BeastSkullBlockEntity,
            BeastSkullJawMotionState
            > motionStates = new WeakHashMap<>();

    public BeastSkullRenderer(
            BlockEntityRendererProvider.Context context
    ) {
    }

    @Override
    public void render(
            BeastSkullBlockEntity be,
            float partialTick,
            PoseStack pose,
            MultiBufferSource buffers,
            int light,
            int overlay
    ) {
        BeastSkullPlacement placement =
                be.getBlockState()
                        .getValue(
                                BeastSkullBlock.PLACEMENT
                        );

        String variant =
                placement.getSerializedName();

        float yaw =
                yawDegrees(be);

        BeastSkullJawMotionState motion =
                motionStates.computeIfAbsent(
                        be,
                        ignored ->
                                new BeastSkullJawMotionState()
                );

        updateMotion(
                be,
                motion,
                yaw
        );

        pose.pushPose();

        pose.translate(
                0.5D,
                0.0D,
                0.5D
        );

        pose.mulPose(
                Axis.YP.rotationDegrees(yaw)
        );

        pose.translate(
                -0.5D,
                0.0D,
                -0.5D
        );

        renderModel(
                model(
                        "the_beast_"
                                + variant
                                + "_static"
                ),
                pose,
                buffers,
                light,
                overlay
        );

        JawPivot pivot =
                jawPivot(placement);

        pose.pushPose();

        pose.translate(
                pivot.x(),
                pivot.y(),
                pivot.z()
        );

        pose.mulPose(
                Axis.XP.rotationDegrees(
                        jawAngle(
                                be,
                                partialTick
                        )
                                + motion.getAngle()
                )
        );

        pose.translate(
                -pivot.x(),
                -pivot.y(),
                -pivot.z()
        );

        renderModel(
                model(
                        "the_beast_"
                                + variant
                                + "_jaw"
                ),
                pose,
                buffers,
                light,
                overlay
        );

        pose.popPose();
        pose.popPose();
    }

    private static float yawDegrees(
            BeastSkullBlockEntity be
    ) {
        BeastSkullPlacement placement =
                be.getBlockState()
                        .getValue(
                                BeastSkullBlock.PLACEMENT
                        );

        if (placement == BeastSkullPlacement.WALL) {
            /*
             * The authored wall model points opposite Minecraft's outward
             * support-face direction, so flip it by 180 degrees.
             */
            Direction outward =
                    be.getBlockState()
                            .getValue(
                                    BeastSkullBlock.FACING
                            );

            return switch (outward) {
                case NORTH -> 180.0F;
                case SOUTH -> 0.0F;
                case EAST -> -90.0F;
                case WEST -> 90.0F;
                default -> 0.0F;
            };
        }

        return be.getBlockState()
                .getValue(
                        BeastSkullBlock.ROTATION
                ) * 22.5F;
    }

    private static JawPivot jawPivot(
            BeastSkullPlacement placement
    ) {
        return switch (placement) {
            case FLOOR ->
                    new JawPivot(
                            8.0D / 16.0D,
                            19.75D / 16.0D,
                            11.0D / 16.0D
                    );

            case WALL ->
                    new JawPivot(
                            8.0D / 16.0D,
                            10.75D / 16.0D,
                            5.0D / 16.0D
                    );

            case CEILING ->
                    new JawPivot(
                            8.0D / 16.0D,
                            2.75D / 16.0D,
                            15.0D / 16.0D
                    );
        };
    }

    private static void updateMotion(
            BeastSkullBlockEntity be,
            BeastSkullJawMotionState motion,
            float yaw
    ) {
        Level level = be.getLevel();

        if (level == null) {
            return;
        }

        double now =
                System.nanoTime() * 1.0E-9D;

        JawPivot pivot =
                jawPivot(
                        be.getBlockState()
                                .getValue(
                                        BeastSkullBlock.PLACEMENT
                                )
                );

        Vec3 localOrigin =
                new Vec3(
                        be.getBlockPos().getX()
                                + pivot.x(),
                        be.getBlockPos().getY()
                                + pivot.y(),
                        be.getBlockPos().getZ()
                                + pivot.z()
                );

        Vec3 worldOrigin =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin
                );

        Vec3 worldX =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin.add(
                                1.0D,
                                0.0D,
                                0.0D
                        )
                ).subtract(worldOrigin);

        Vec3 worldZ =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin.add(
                                0.0D,
                                0.0D,
                                1.0D
                        )
                ).subtract(worldOrigin);

        if (
                worldX.lengthSqr() < 0.000001D
                        || worldZ.lengthSqr()
                        < 0.000001D
        ) {
            return;
        }

        worldX = worldX.normalize();
        worldZ = worldZ.normalize();

        double radians =
                Math.toRadians(yaw);

        double cos =
                Math.cos(radians);

        double sin =
                Math.sin(radians);

        Vec3 localForward =
                worldX.scale(sin)
                        .add(
                                worldZ.scale(cos)
                        )
                        .normalize();

        motion.update(
                now,
                worldOrigin,
                localForward
        );
    }

    private static float jawAngle(
            BeastSkullBlockEntity be,
            float partialTick
    ) {
        if (
                be.getLevel() == null
                        || be.animationStart()
                        == Long.MIN_VALUE
        ) {
            return 0.0F;
        }

        float t =
                be.getLevel().getGameTime()
                        + partialTick
                        - be.animationStart();

        return switch (be.animation()) {
            case BeastSkullBlockEntity.ANIMATION_SNAP -> {
                if (t < 8.0F) {
                    yield ease(t / 8.0F) * 42.0F;
                }

                if (t < 13.0F) {
                    yield 42.0F;
                }

                if (t < 24.0F) {
                    yield (
                            1.0F
                                    - ease(
                                    (t - 13.0F)
                                            / 11.0F
                            )
                    ) * 42.0F;
                }

                yield 0.0F;
            }

            case BeastSkullBlockEntity.ANIMATION_CHEW -> {
                float phase =
                        (t % 24.0F)
                                / 24.0F;

                yield 12.0F
                        + (
                        0.5F
                                - 0.5F
                                * (float) Math.cos(
                                phase
                                        * Math.PI
                                        * 2.0D
                        )
                ) * 24.0F;
            }

            case BeastSkullBlockEntity.ANIMATION_HARD_BITE ->
                    t < 5.0F
                            ? (
                            1.0F
                                    - ease(t / 5.0F)
                    ) * 35.0F
                            : 0.0F;

            default -> 0.0F;
        };
    }

    private static float ease(float value) {
        float x =
                Math.max(
                        0.0F,
                        Math.min(
                                1.0F,
                                value
                        )
                );

        return x
                * x
                * (
                3.0F
                        - 2.0F
                        * x
        );
    }

    private static ResourceLocation model(
            String name
    ) {
        return ResourceLocation.fromNamespaceAndPath(
                DroingosDecor.MOD_ID,
                "block/" + name
        );
    }

    private static void renderModel(
            ResourceLocation location,
            PoseStack pose,
            MultiBufferSource buffers,
            int light,
            int overlay
    ) {
        Minecraft minecraft =
                Minecraft.getInstance();

        BakedModel baked =
                minecraft
                        .getModelManager()
                        .getModel(
                                ModelResourceLocation
                                        .standalone(
                                                location
                                        )
                        );

        BlockRenderDispatcher dispatcher =
                minecraft.getBlockRenderer();

        dispatcher.getModelRenderer()
                .renderModel(
                        pose.last(),
                        buffers.getBuffer(
                                RenderType.cutout()
                        ),
                        Blocks.AIR
                                .defaultBlockState(),
                        baked,
                        1.0F,
                        1.0F,
                        1.0F,
                        light,
                        overlay,
                        ModelData.EMPTY,
                        RenderType.cutout()
                );
    }

    @Override
    public boolean shouldRenderOffScreen(
            BeastSkullBlockEntity blockEntity
    ) {
        return true;
    }

    private record JawPivot(
            double x,
            double y,
            double z
    ) {
    }
}