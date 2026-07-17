package net.droingo.decor.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;
import dev.ryanhcode.sable.Sable;
import net.droingo.decor.api.BobbleheadRenderDefinition;
import net.droingo.decor.api.DecorDefinition;
import net.droingo.decor.client.animation.BobbleheadInteractionPulses;
import net.droingo.decor.client.animation.BobbleheadMotionState;
import net.droingo.decor.content.DecorContainerBlockEntity;
import net.droingo.decor.registry.DecorDefinitionRegistry;
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
import org.joml.Vector3d;

import java.util.Map;
import java.util.WeakHashMap;

public final class DecorContainerRenderer implements BlockEntityRenderer<DecorContainerBlockEntity> {
    private final Map<DecorContainerBlockEntity, BobbleheadMotionState[]> motionStates = new WeakHashMap<>();
    private final BlockRenderDispatcher blockRenderer;

    public DecorContainerRenderer(BlockEntityRendererProvider.Context context) {
        this.blockRenderer = context.getBlockRenderDispatcher();
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
            ResourceLocation id = blockEntity.getDecorId(slot);
            DecorDefinition definition = id == null ? null : DecorDefinitionRegistry.get(id);

            if (definition == null || definition.bobbleheadRender() == null) {
                continue;
            }

            renderBobblehead(
                    blockEntity,
                    definition,
                    slot,
                    partialTick,
                    poseStack,
                    buffers,
                    packedLight,
                    packedOverlay
            );
        }
    }

    private void renderBobblehead(
            DecorContainerBlockEntity blockEntity,
            DecorDefinition definition,
            int slot,
            float partialTick,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        BobbleheadRenderDefinition render = definition.bobbleheadRender();
        double centreX = slot % 2 == 0 ? 0.25D : 0.75D;
        double centreZ = slot < 2 ? 0.25D : 0.75D;
        float yawDegrees = blockEntity.getRotation(slot) * 22.5F;

        BobbleheadMotionState motion = getMotionState(blockEntity, slot);
        updateMotion(blockEntity, motion, centreX, centreZ, yawDegrees, render.pivot().y, partialTick);

        poseStack.pushPose();
        poseStack.translate(centreX, 0.0D, centreZ);
        poseStack.mulPose(Axis.YP.rotationDegrees(yawDegrees));
        poseStack.scale(render.scale(), render.scale(), render.scale());
        poseStack.translate(-0.5D, 0.0D, -0.5D);

        renderModel(poseStack, buffers, render.bodyModel(), packedLight, packedOverlay);
        renderMovingPart(poseStack, buffers, render, motion, packedLight, packedOverlay);
        poseStack.popPose();
    }

    private void updateMotion(
            DecorContainerBlockEntity blockEntity,
            BobbleheadMotionState motion,
            double centreX,
            double centreZ,
            float yawDegrees,
            double pivotY,
            float partialTick
    ) {
        Level level = blockEntity.getLevel();
        if (level == null) {
            return;
        }

        Vec3 localOrigin = new Vec3(
                blockEntity.getBlockPos().getX() + centreX,
                blockEntity.getBlockPos().getY() + pivotY,
                blockEntity.getBlockPos().getZ() + centreZ
        );

        Vec3 worldOrigin = Sable.HELPER.projectOutOfSubLevel(level, localOrigin);
        Vec3 worldLocalX = Sable.HELPER.projectOutOfSubLevel(level, localOrigin.add(1.0D, 0.0D, 0.0D)).subtract(worldOrigin);
        Vec3 worldLocalZ = Sable.HELPER.projectOutOfSubLevel(level, localOrigin.add(0.0D, 0.0D, 1.0D)).subtract(worldOrigin);

        if (worldLocalX.lengthSqr() < 0.000001D || worldLocalZ.lengthSqr() < 0.000001D) {
            return;
        }

        worldLocalX = worldLocalX.normalize();
        worldLocalZ = worldLocalZ.normalize();

        double yawRadians = Math.toRadians(yawDegrees);
        double cos = Math.cos(yawRadians);
        double sin = Math.sin(yawRadians);

        Vec3 decorRight = worldLocalX.scale(cos).add(worldLocalZ.scale(sin)).normalize();
        Vec3 decorForward = worldLocalX.scale(sin).add(worldLocalZ.scale(-cos)).normalize();

        motion.update(level.getGameTime() + partialTick, worldOrigin, decorRight, decorForward);
    }

    private BobbleheadMotionState getMotionState(DecorContainerBlockEntity blockEntity, int slot) {
        BobbleheadMotionState[] states = motionStates.computeIfAbsent(blockEntity, ignored -> new BobbleheadMotionState[4]);
        if (states[slot] == null) {
            states[slot] = new BobbleheadMotionState();
        }
        return states[slot];
    }

    private void renderMovingPart(
            PoseStack poseStack,
            MultiBufferSource buffers,
            BobbleheadRenderDefinition render,
            BobbleheadMotionState motion,
            int packedLight,
            int packedOverlay
    ) {
        Vector3d pivot = render.pivot();
        poseStack.pushPose();
        poseStack.translate(pivot.x, pivot.y, pivot.z);
        poseStack.mulPose(Axis.XP.rotationDegrees(motion.getPitchDegrees()));
        poseStack.mulPose(Axis.ZP.rotationDegrees(motion.getRollDegrees()));
        poseStack.translate(-pivot.x, -pivot.y, -pivot.z);
        renderModel(poseStack, buffers, render.movingModel(), packedLight, packedOverlay);
        poseStack.popPose();
    }

    private void renderModel(
            PoseStack poseStack,
            MultiBufferSource buffers,
            ResourceLocation location,
            int light,
            int overlay
    ) {
        BakedModel model = Minecraft.getInstance().getModelManager().getModel(ModelResourceLocation.standalone(location));
        VertexConsumer consumer = buffers.getBuffer(RenderType.cutout());

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