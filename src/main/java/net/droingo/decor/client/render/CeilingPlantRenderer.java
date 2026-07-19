package net.droingo.decor.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;
import dev.ryanhcode.sable.Sable;
import net.droingo.decor.DroingosDecor;
import net.droingo.decor.client.animation.CeilingPendulumMotionState;
import net.droingo.decor.client.animation.VineChainMotionState;
import net.droingo.decor.content.CeilingPlantBlock;
import net.droingo.decor.content.CeilingPlantBlockEntity;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.block.BlockRenderDispatcher;
import net.minecraft.client.renderer.blockentity.BlockEntityRenderer;
import net.minecraft.client.renderer.blockentity.BlockEntityRendererProvider;
import net.minecraft.client.resources.model.BakedModel;
import net.minecraft.client.resources.model.ModelResourceLocation;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.phys.Vec3;
import net.neoforged.neoforge.client.model.data.ModelData;

import java.util.Map;
import java.util.WeakHashMap;

public final class CeilingPlantRenderer
        implements BlockEntityRenderer<CeilingPlantBlockEntity> {

    private static final ResourceLocation POT_VINE_0 =
            model("potted_plant_ceiling_pot_vine0");

    private static final ResourceLocation VINE_1 =
            model("potted_plant_ceiling_vine1");

    private static final ResourceLocation VINE_2 =
            model("potted_plant_ceiling_vine2");

    private static final ResourceLocation VINE_3 =
            model("potted_plant_ceiling_vine3");

    private static final double ROOT_X = 8.0D / 16.0D;
    private static final double ROOT_Y = 16.0D / 16.0D;
    private static final double ROOT_Z = 8.0D / 16.0D;

    private static final double[][] VINE_PIVOTS = {
            {
                    12.0D / 16.0D,
                    10.0D / 16.0D,
                    8.0D / 16.0D
            },
            {
                    12.0D / 16.0D,
                    6.1D / 16.0D,
                    7.9D / 16.0D
            },
            {
                    12.0D / 16.0D,
                    1.1D / 16.0D,
                    8.0D / 16.0D
            }
    };

    private final Map<
            CeilingPlantBlockEntity,
            PlantMotion
            > motionStates = new WeakHashMap<>();

    private final BlockRenderDispatcher blockRenderer;

    public CeilingPlantRenderer(
            BlockEntityRendererProvider.Context context
    ) {
        blockRenderer =
                context.getBlockRenderDispatcher();
    }

    @Override
    public void render(
            CeilingPlantBlockEntity blockEntity,
            float partialTick,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        PlantMotion motion =
                motionStates.computeIfAbsent(
                        blockEntity,
                        ignored -> new PlantMotion()
                );

        float frameTicks = updateMotion(
                blockEntity,
                motion
        );

        motion.vines.update(
                motion.root.getPitch(),
                motion.root.getRoll(),
                frameTicks
        );

        float yaw =
                blockEntity.getBlockState()
                        .getValue(
                                CeilingPlantBlock.ROTATION
                        )
                        * 22.5F;

        poseStack.pushPose();

        /*
         * Authored yaw rotation around the block centre.
         */
        poseStack.translate(0.5D, 0.5D, 0.5D);
        poseStack.mulPose(
                Axis.YP.rotationDegrees(yaw)
        );
        poseStack.translate(-0.5D, -0.5D, -0.5D);

        /*
         * Whole plant swings from the ceiling attachment.
         */
        poseStack.translate(
                ROOT_X,
                ROOT_Y,
                ROOT_Z
        );

        poseStack.mulPose(
                Axis.XP.rotationDegrees(
                        motion.root.getPitch()
                )
        );

        poseStack.mulPose(
                Axis.ZP.rotationDegrees(
                        motion.root.getRoll()
                )
        );

        poseStack.translate(
                -ROOT_X,
                -ROOT_Y,
                -ROOT_Z
        );

        renderModel(
                poseStack,
                buffers,
                POT_VINE_0,
                packedLight,
                packedOverlay
        );

        renderVineChain(
                poseStack,
                buffers,
                motion,
                packedLight,
                packedOverlay
        );

        poseStack.popPose();
    }

    private float updateMotion(
            CeilingPlantBlockEntity blockEntity,
            PlantMotion motion
    ) {
        Level level = blockEntity.getLevel();

        if (level == null) {
            return 0.0F;
        }

        double now =
                System.nanoTime() * 1.0E-9D;

        float frameTicks;

        if (
                motion.lastRenderSeconds == 0.0D
                        || now <= motion.lastRenderSeconds
        ) {
            frameTicks = 0.0F;
        } else {
            frameTicks = (float) Math.min(
                    2.0D,
                    (now - motion.lastRenderSeconds)
                            * 20.0D
            );
        }

        motion.lastRenderSeconds = now;

        Vec3 localOrigin = new Vec3(
                blockEntity.getBlockPos().getX()
                        + ROOT_X,
                blockEntity.getBlockPos().getY()
                        + ROOT_Y,
                blockEntity.getBlockPos().getZ()
                        + ROOT_Z
        );

        Vec3 worldOrigin =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin
                );

        Vec3 worldX =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin.add(1.0D, 0.0D, 0.0D)
                ).subtract(worldOrigin);

        Vec3 worldY =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin.add(0.0D, 1.0D, 0.0D)
                ).subtract(worldOrigin);

        Vec3 worldZ =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin.add(0.0D, 0.0D, 1.0D)
                ).subtract(worldOrigin);

        if (
                worldX.lengthSqr() < 0.000001D
                        || worldY.lengthSqr()
                        < 0.000001D
                        || worldZ.lengthSqr()
                        < 0.000001D
        ) {
            return frameTicks;
        }

        double yawRadians = Math.toRadians(
                blockEntity.getBlockState()
                        .getValue(
                                CeilingPlantBlock.ROTATION
                        )
                        * 22.5D
        );

        double cos = Math.cos(yawRadians);
        double sin = Math.sin(yawRadians);

        worldX = worldX.normalize();
        worldY = worldY.normalize();
        worldZ = worldZ.normalize();

        Vec3 localRight =
                worldX.scale(cos)
                        .add(
                                worldZ.scale(-sin)
                        )
                        .normalize();

        Vec3 localForward =
                worldX.scale(sin)
                        .add(
                                worldZ.scale(cos)
                        )
                        .normalize();

        motion.root.update(
                now,
                worldOrigin,
                localRight,
                worldY,
                localForward
        );

        return frameTicks;
    }

    private void renderVineChain(
            PoseStack poseStack,
            MultiBufferSource buffers,
            PlantMotion motion,
            int packedLight,
            int packedOverlay
    ) {
        ResourceLocation[] models = {
                VINE_1,
                VINE_2,
                VINE_3
        };

        poseStack.pushPose();

        for (int index = 0; index < 3; index++) {
            double[] pivot =
                    VINE_PIVOTS[index];

            poseStack.translate(
                    pivot[0],
                    pivot[1],
                    pivot[2]
            );

            poseStack.mulPose(
                    Axis.XP.rotationDegrees(
                            motion.vines.getPitch(index)
                    )
            );

            poseStack.mulPose(
                    Axis.ZP.rotationDegrees(
                            motion.vines.getRoll(index)
                    )
            );

            poseStack.translate(
                    -pivot[0],
                    -pivot[1],
                    -pivot[2]
            );

            renderModel(
                    poseStack,
                    buffers,
                    models[index],
                    packedLight,
                    packedOverlay
            );
        }

        poseStack.popPose();
    }

    private void renderModel(
            PoseStack poseStack,
            MultiBufferSource buffers,
            ResourceLocation location,
            int light,
            int overlay
    ) {
        BakedModel model =
                Minecraft.getInstance()
                        .getModelManager()
                        .getModel(
                                ModelResourceLocation.standalone(
                                        location
                                )
                        );

        VertexConsumer consumer =
                buffers.getBuffer(
                        RenderType.cutout()
                );

        blockRenderer.getModelRenderer().renderModel(
                poseStack.last(),
                consumer,
                Blocks.AIR.defaultBlockState(),
                model,
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
            CeilingPlantBlockEntity blockEntity
    ) {
        return true;
    }

    private static ResourceLocation model(String name) {
        return ResourceLocation.fromNamespaceAndPath(
                DroingosDecor.MOD_ID,
                "block/" + name
        );
    }

    private static final class PlantMotion {
        private final CeilingPendulumMotionState root =
                new CeilingPendulumMotionState();

        private final VineChainMotionState vines =
                new VineChainMotionState();

        private double lastRenderSeconds;
    }
}