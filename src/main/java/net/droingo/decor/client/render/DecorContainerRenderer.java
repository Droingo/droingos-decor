package net.droingo.decor.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;
import net.droingo.decor.DroingosDecor;
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
import net.minecraft.world.level.block.Blocks;
import net.neoforged.neoforge.client.model.data.ModelData;

public final class DecorContainerRenderer
        implements BlockEntityRenderer<DecorContainerBlockEntity> {

    private static final float PARROT_SCALE = 1.5F;

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
            ResourceLocation decorId = blockEntity.getDecorId(slot);

            if (
                    decorId == null
                            || !decorId.getPath().equals("bobble_parrot")
            ) {
                continue;
            }

            renderParrot(
                    blockEntity,
                    slot,
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
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        double centreX = slot % 2 == 0 ? 0.25D : 0.75D;
        double centreZ = slot < 2 ? 0.25D : 0.75D;

        poseStack.pushPose();

        /*
         * Move the model's centre to the selected quarter-block slot.
         *
         * The model itself was authored around Minecraft model coordinate
         * 8, which corresponds to 0.5 blocks.
         */
        poseStack.translate(centreX, 0.0D, centreZ);

        poseStack.mulPose(
                Axis.YP.rotationDegrees(
                        blockEntity.getRotation(slot) * 22.5F
                )
        );

        /*
         * Scale around the model's feet/centre rather than around the corner
         * of the Minecraft block.
         */
        poseStack.scale(
                PARROT_SCALE,
                PARROT_SCALE,
                PARROT_SCALE
        );

        poseStack.translate(-0.5D, 0.0D, -0.5D);

        renderModel(
                poseStack,
                buffers,
                PARROT_BODY,
                packedLight,
                packedOverlay
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
        BakedModel model = Minecraft.getInstance()
                .getModelManager()
                .getModel(location);

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