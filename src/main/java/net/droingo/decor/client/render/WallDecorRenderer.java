package net.droingo.decor.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;
import dev.ryanhcode.sable.Sable;
import net.droingo.decor.api.DecorDefinition;
import net.droingo.decor.api.GravityWallRenderDefinition;
import net.droingo.decor.client.animation.HangingGravityMotionState;
import net.droingo.decor.content.WallDecorBlock;
import net.droingo.decor.content.WallDecorBlockEntity;
import net.droingo.decor.registry.DecorDefinitionRegistry;
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
import org.joml.Vector3d;

import java.util.Map;
import java.util.WeakHashMap;

public final class WallDecorRenderer
        implements BlockEntityRenderer<WallDecorBlockEntity> {

    private final Map<WallDecorBlockEntity, HangingGravityMotionState> motionStates =
            new WeakHashMap<>();

    private final BlockRenderDispatcher blockRenderer;

    public WallDecorRenderer(
            BlockEntityRendererProvider.Context context
    ) {
        this.blockRenderer =
                context.getBlockRenderDispatcher();
    }

    @Override
    public void render(
            WallDecorBlockEntity blockEntity,
            float partialTick,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        ResourceLocation decorId =
                blockEntity.getDecorId();

        if (decorId == null) {
            return;
        }

        DecorDefinition definition =
                DecorDefinitionRegistry.get(decorId);

        if (
                definition == null
                        || definition.gravityWallRender() == null
        ) {
            return;
        }

        GravityWallRenderDefinition renderDefinition =
                definition.gravityWallRender();

        Direction supportDirection =
                blockEntity.getBlockState()
                        .getValue(WallDecorBlock.FACING);

        float yawDegrees =
                yawForSupport(supportDirection);

        HangingGravityMotionState motion =
                motionStates.computeIfAbsent(
                        blockEntity,
                        ignored ->
                                new HangingGravityMotionState()
                );

        updateGravityMotion(
                blockEntity,
                renderDefinition,
                yawDegrees,
                partialTick,
                motion
        );

        poseStack.pushPose();

        /*
         * Rotate the complete decoration to match the wall face.
         */
        poseStack.translate(
                0.5D,
                0.5D,
                0.5D
        );

        poseStack.mulPose(
                Axis.YP.rotationDegrees(yawDegrees)
        );

        poseStack.translate(
                -0.5D,
                -0.5D,
                -0.5D
        );

        poseStack.scale(
                renderDefinition.scale(),
                renderDefinition.scale(),
                renderDefinition.scale()
        );

        /*
         * The nail remains fixed to the wall.
         */
        renderModel(
                poseStack,
                buffers,
                renderDefinition.fixedModel(),
                packedLight,
                packedOverlay
        );

        /*
         * The sweater rotates separately around its hanger pivot.
         */
        renderMovingModel(
                poseStack,
                buffers,
                renderDefinition,
                motion,
                packedLight,
                packedOverlay
        );

        poseStack.popPose();
    }

    private void updateGravityMotion(
            WallDecorBlockEntity blockEntity,
            GravityWallRenderDefinition renderDefinition,
            float yawDegrees,
            float partialTick,
            HangingGravityMotionState motion
    ) {
        Level level =
                blockEntity.getLevel();

        if (level == null) {
            return;
        }

        Vector3d pivot =
                renderDefinition.pivot();

        double yawRadians =
                Math.toRadians(yawDegrees);

        double cos =
                Math.cos(yawRadians);

        double sin =
                Math.sin(yawRadians);

        /*
         * Rotate the authored model pivot around the block centre so the
         * projected sample point follows the wall-facing model correctly.
         */
        double offsetX =
                pivot.x - 0.5D;

        double offsetZ =
                pivot.z - 0.5D;

        double rotatedOffsetX =
                offsetX * cos
                        + offsetZ * sin;

        double rotatedOffsetZ =
                -offsetX * sin
                        + offsetZ * cos;

        Vec3 localOrigin = new Vec3(
                blockEntity.getBlockPos().getX()
                        + 0.5D
                        + rotatedOffsetX,
                blockEntity.getBlockPos().getY()
                        + pivot.y,
                blockEntity.getBlockPos().getZ()
                        + 0.5D
                        + rotatedOffsetZ
        );

        /*
         * Project the pivot and local basis into ordinary global world space.
         * This works for both the normal world and Sable sublevels.
         */
        Vec3 worldOrigin =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin
                );

        Vec3 worldLocalX =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin.add(
                                1.0D,
                                0.0D,
                                0.0D
                        )
                ).subtract(worldOrigin);

        Vec3 worldLocalY =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin.add(
                                0.0D,
                                1.0D,
                                0.0D
                        )
                ).subtract(worldOrigin);

        Vec3 worldLocalZ =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin.add(
                                0.0D,
                                0.0D,
                                1.0D
                        )
                ).subtract(worldOrigin);

        if (
                worldLocalX.lengthSqr() < 0.000001D
                        || worldLocalY.lengthSqr() < 0.000001D
                        || worldLocalZ.lengthSqr() < 0.000001D
        ) {
            return;
        }

        worldLocalX =
                worldLocalX.normalize();

        worldLocalY =
                worldLocalY.normalize();

        worldLocalZ =
                worldLocalZ.normalize();

        /*
         * Decoration-local basis after its wall-facing yaw is applied.
         */
        Vec3 decorRight =
                worldLocalX.scale(cos)
                        .add(
                                worldLocalZ.scale(sin)
                        )
                        .normalize();

        Vec3 decorUp =
                worldLocalY;

        /*
         * The model is authored against local +Z at the wall.
         * Local -Z therefore points away from the wall.
         */
        Vec3 towardWall =
                worldLocalX.scale(-sin)
                        .add(
                                worldLocalZ.scale(cos)
                        )
                        .normalize();

        Vec3 awayFromWall =
                towardWall.scale(-1.0D);

        /*
         * HangingGravityMotionState combines:
         *
         * - world gravity
         * - vehicle acceleration and braking
         * - crash impulses
         * - the current Sable orientation
         *
         * It also applies the median velocity filter used to suppress
         * periodic Sable projection corrections.
         */
        motion.update(
                level.getGameTime() + partialTick,
                worldOrigin,
                decorRight,
                decorUp,
                awayFromWall
        );
    }

    private void renderMovingModel(
            PoseStack poseStack,
            MultiBufferSource buffers,
            GravityWallRenderDefinition renderDefinition,
            HangingGravityMotionState motion,
            int packedLight,
            int packedOverlay
    ) {
        Vector3d pivot =
                renderDefinition.pivot();

        poseStack.pushPose();

        /*
         * Move to the hanger hook.
         */
        poseStack.translate(
                pivot.x,
                pivot.y,
                pivot.z
        );

        /*
         * X rotates away from the wall.
         *
         * Z rotates parallel to the wall and supports the complete upside-down
         * orientation when the sublevel rolls beyond 90 degrees.
         */
        poseStack.mulPose(
                Axis.XP.rotationDegrees(
                        motion.getAwayAngle()
                )
        );

        poseStack.mulPose(
                Axis.ZP.rotationDegrees(
                        motion.getSideAngle()
                )
        );

        /*
         * Move back from the pivot before rendering the cloth model.
         */
        poseStack.translate(
                -pivot.x,
                -pivot.y,
                -pivot.z
        );

        renderModel(
                poseStack,
                buffers,
                renderDefinition.movingModel(),
                packedLight,
                packedOverlay
        );

        poseStack.popPose();
    }

    private void renderModel(
            PoseStack poseStack,
            MultiBufferSource buffers,
            ResourceLocation location,
            int packedLight,
            int packedOverlay
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
                packedLight,
                packedOverlay,
                ModelData.EMPTY,
                RenderType.cutout()
        );
    }

    private static float yawForSupport(
            Direction supportDirection
    ) {
        return switch (supportDirection) {
            case SOUTH -> 0.0F;
            case EAST -> 90.0F;
            case NORTH -> 180.0F;
            case WEST -> -90.0F;
            default -> 0.0F;
        };
    }
}