package net.droingo.decor.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;
import dev.ryanhcode.sable.Sable;
import net.droingo.decor.DroingosDecor;
import net.droingo.decor.client.animation.BobbleheadMotionState;
import net.droingo.decor.content.DecorContainerBlockEntity;
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

public final class DecorContainerRenderer
        implements BlockEntityRenderer<DecorContainerBlockEntity> {

    private static final float PARROT_SCALE = 1.5F;

    /*
     * Head pivot taken from the original Blockbench head group:
     *
     * [8.0, 3.2, 7.3] pixels
     *
     * Converted into block-model units.
     */
    private static final double HEAD_PIVOT_X =
            8.0D / 16.0D;

    private static final double HEAD_PIVOT_Y =
            3.2D / 16.0D;

    private static final double HEAD_PIVOT_Z =
            7.3D / 16.0D;

    private static final ModelResourceLocation PARROT_BODY =
            ModelResourceLocation.standalone(
                    ResourceLocation.fromNamespaceAndPath(
                            DroingosDecor.MOD_ID,
                            "block/bobble_parrot_body"
                    )
            );

    private static final ModelResourceLocation PARROT_HEAD =
            ModelResourceLocation.standalone(
                    ResourceLocation.fromNamespaceAndPath(
                            DroingosDecor.MOD_ID,
                            "block/bobble_parrot_head"
                    )
            );

    /*
     * Client-only transient animation data.
     *
     * Weak keys allow states to disappear when their block entities unload.
     */
    private final Map<
            DecorContainerBlockEntity,
            BobbleheadMotionState[]
            > motionStates = new WeakHashMap<>();

    private final BlockRenderDispatcher blockRenderer;

    public DecorContainerRenderer(
            BlockEntityRendererProvider.Context context
    ) {
        this.blockRenderer =
                context.getBlockRenderDispatcher();
    }

    @Override
    public void render(
            DecorContainerBlockEntity blockEntity,
            float partialTick,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        for (int slot = 0; slot < 4; slot++) {
            ResourceLocation decorId =
                    blockEntity.getDecorId(slot);

            if (
                    decorId == null
                            || !decorId.getPath()
                            .equals("bobble_parrot")
            ) {
                continue;
            }

            renderParrot(
                    blockEntity,
                    slot,
                    partialTick,
                    poseStack,
                    buffers,
                    packedLight,
                    packedOverlay
            );
        }
    }

    private void renderParrot(
            DecorContainerBlockEntity blockEntity,
            int slot,
            float partialTick,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        double centreX =
                slot % 2 == 0
                        ? 0.25D
                        : 0.75D;

        double centreZ =
                slot < 2
                        ? 0.25D
                        : 0.75D;

        int rotationStep =
                blockEntity.getRotation(slot);

        float yawDegrees =
                rotationStep * 22.5F;

        BobbleheadMotionState motion =
                getMotionState(blockEntity, slot);

        updateMotion(
                blockEntity,
                motion,
                centreX,
                centreZ,
                yawDegrees,
                partialTick
        );

        poseStack.pushPose();

        poseStack.translate(
                centreX,
                0.0D,
                centreZ
        );

        poseStack.mulPose(
                Axis.YP.rotationDegrees(yawDegrees)
        );

        poseStack.scale(
                PARROT_SCALE,
                PARROT_SCALE,
                PARROT_SCALE
        );

        poseStack.translate(
                -0.5D,
                0.0D,
                -0.5D
        );

        renderModel(
                poseStack,
                buffers,
                PARROT_BODY,
                packedLight,
                packedOverlay
        );

        renderAnimatedHead(
                poseStack,
                buffers,
                motion,
                packedLight,
                packedOverlay
        );

        poseStack.popPose();
    }

    private void updateMotion(
            DecorContainerBlockEntity blockEntity,
            BobbleheadMotionState motion,
            double centreX,
            double centreZ,
            float yawDegrees,
            float partialTick
    ) {
        Level level = blockEntity.getLevel();

        if (level == null) {
            return;
        }

        Vec3 localOrigin = new Vec3(
                blockEntity.getBlockPos().getX()
                        + centreX,
                blockEntity.getBlockPos().getY()
                        + HEAD_PIVOT_Y,
                blockEntity.getBlockPos().getZ()
                        + centreZ
        );

        /*
         * Project the parrot's local position and basis directions into
         * ordinary global world space.
         */
        Vec3 worldOrigin =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin
                );

        Vec3 worldLocalX =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin.add(1.0D, 0.0D, 0.0D)
                ).subtract(worldOrigin);

        Vec3 worldLocalZ =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin.add(0.0D, 0.0D, 1.0D)
                ).subtract(worldOrigin);

        if (
                worldLocalX.lengthSqr() < 0.000001D
                        || worldLocalZ.lengthSqr() < 0.000001D
        ) {
            return;
        }

        worldLocalX = worldLocalX.normalize();
        worldLocalZ = worldLocalZ.normalize();

        double yawRadians =
                Math.toRadians(yawDegrees);

        double cos =
                Math.cos(yawRadians);

        double sin =
                Math.sin(yawRadians);

        /*
         * Rotate the sublevel's local basis to match the parrot's own
         * placement rotation.
         */
        /*
         * The Blockbench parrot faces local negative Z, not positive Z.
         *
         * Axis.YP rotation transforms:
         *
         * local +X into the parrot's visible right direction
         * local -Z into the parrot's visible forward direction
         *
         * Defining these correctly is particularly important at diagonal
         * placement rotations.
         */
        /*
         * Match the exact positive-Y rotation used by the PoseStack above.
         *
         * The parrot model faces local -Z:
         *
         * right   = rotated local +X
         * forward = rotated local -Z
         */
        Vec3 parrotRight =
                worldLocalX.scale(cos)
                        .add(worldLocalZ.scale(sin))
                        .normalize();

        Vec3 parrotForward =
                worldLocalX.scale(sin)
                        .add(worldLocalZ.scale(-cos))
                        .normalize();
        double timelineTime =
                level.getGameTime() + partialTick;

        motion.update(
                timelineTime,
                worldOrigin,
                parrotRight,
                parrotForward
        );
    }

    private BobbleheadMotionState getMotionState(
            DecorContainerBlockEntity blockEntity,
            int slot
    ) {
        BobbleheadMotionState[] states =
                motionStates.computeIfAbsent(
                        blockEntity,
                        ignored ->
                                new BobbleheadMotionState[4]
                );

        if (states[slot] == null) {
            states[slot] =
                    new BobbleheadMotionState();
        }

        return states[slot];
    }

    private void renderAnimatedHead(
            PoseStack poseStack,
            MultiBufferSource buffers,
            BobbleheadMotionState motion,
            int packedLight,
            int packedOverlay
    ) {
        poseStack.pushPose();

        /*
         * Rotate around the neck spring rather than around the centre of
         * the block model.
         */
        poseStack.translate(
                HEAD_PIVOT_X,
                HEAD_PIVOT_Y,
                HEAD_PIVOT_Z
        );

        poseStack.mulPose(
                Axis.XP.rotationDegrees(
                        motion.getPitchDegrees()
                )
        );

        poseStack.mulPose(
                Axis.ZP.rotationDegrees(
                        motion.getRollDegrees()
                )
        );

        poseStack.translate(
                -HEAD_PIVOT_X,
                -HEAD_PIVOT_Y,
                -HEAD_PIVOT_Z
        );

        renderModel(
                poseStack,
                buffers,
                PARROT_HEAD,
                packedLight,
                packedOverlay
        );

        poseStack.popPose();
    }

    private void renderModel(
            PoseStack poseStack,
            MultiBufferSource buffers,
            ModelResourceLocation location,
            int light,
            int overlay
    ) {
        BakedModel model =
                Minecraft.getInstance()
                        .getModelManager()
                        .getModel(location);

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
}