package net.droingo.decor.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;
import net.droingo.decor.DroingosDecor;
import net.droingo.decor.content.HalfDecorBlockEntity;
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

public final class HalfDecorRenderer
        implements BlockEntityRenderer<HalfDecorBlockEntity> {

    private static final ResourceLocation BODY_MODEL =
            model("earth_roamer_body");

    private static final ResourceLocation FRONT_WHEELS_MODEL =
            model("earth_roamer_front_wheels");

    private static final ResourceLocation REAR_WHEELS_MODEL =
            model("earth_roamer_rear_wheels");

    private static final double ANIMATION_LENGTH_TICKS = 18.0D;
    private static final double MAX_TRAVEL = 2.2D / 16.0D;
    private static final double WHEEL_RADIUS = 1.5D / 16.0D;

    private final BlockRenderDispatcher blockRenderer;

    public HalfDecorRenderer(
            BlockEntityRendererProvider.Context context
    ) {
        blockRenderer = context.getBlockRenderDispatcher();
    }

    @Override
    public void render(
            HalfDecorBlockEntity blockEntity,
            float partialTick,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        float yawDegrees =
                blockEntity.getRotation() * 22.5F;

        double progress = animationProgress(
                blockEntity,
                partialTick
        );

        double travel = travelAt(progress);
        double wheelDegrees =
                Math.toDegrees(travel / WHEEL_RADIUS);

        poseStack.pushPose();

        poseStack.translate(0.5D, 0.03125D, 0.5D);
        poseStack.mulPose(
                Axis.YP.rotationDegrees(yawDegrees)
        );

        /*
         * The model's front is local -Z, so positive play travel is -Z.
         */
        poseStack.translate(
                -0.5D,
                0.0D,
                -0.5D - travel
        );

        renderModel(
                poseStack,
                buffers,
                BODY_MODEL,
                packedLight,
                packedOverlay
        );

        renderWheels(
                poseStack,
                buffers,
                FRONT_WHEELS_MODEL,
                8.0D / 16.0D,
                1.5D / 16.0D,
                3.5D / 16.0D,
                wheelDegrees,
                packedLight,
                packedOverlay
        );

        renderWheels(
                poseStack,
                buffers,
                REAR_WHEELS_MODEL,
                8.0D / 16.0D,
                1.5D / 16.0D,
                10.5D / 16.0D,
                wheelDegrees,
                packedLight,
                packedOverlay
        );

        poseStack.popPose();
    }

    private static double animationProgress(
            HalfDecorBlockEntity blockEntity,
            float partialTick
    ) {
        if (
                blockEntity.getLevel() == null
                        || blockEntity.getAnimationStartTick()
                        == Long.MIN_VALUE
        ) {
            return 1.0D;
        }

        double elapsed =
                blockEntity.getLevel().getGameTime()
                        + partialTick
                        - blockEntity.getAnimationStartTick();

        return Math.max(
                0.0D,
                Math.min(
                        1.0D,
                        elapsed / ANIMATION_LENGTH_TICKS
                )
        );
    }

    private static double travelAt(double progress) {
        if (progress >= 1.0D) {
            return 0.0D;
        }

        /*
         * A smooth forward push followed by a smooth pull back.
         * sin(pi * progress) guarantees exact rest at both ends.
         */
        return Math.sin(Math.PI * progress)
                * MAX_TRAVEL;
    }

    private void renderWheels(
            PoseStack poseStack,
            MultiBufferSource buffers,
            ResourceLocation model,
            double pivotX,
            double pivotY,
            double pivotZ,
            double wheelDegrees,
            int packedLight,
            int packedOverlay
    ) {
        poseStack.pushPose();
        poseStack.translate(pivotX, pivotY, pivotZ);

        /*
         * Wheel axles run across X, so rolling is rotation around X.
         */
        poseStack.mulPose(
                Axis.XP.rotationDegrees(
                        (float) -wheelDegrees
                )
        );

        poseStack.translate(-pivotX, -pivotY, -pivotZ);

        renderModel(
                poseStack,
                buffers,
                model,
                packedLight,
                packedOverlay
        );

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
                buffers.getBuffer(RenderType.cutout());

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

    private static ResourceLocation model(String name) {
        return ResourceLocation.fromNamespaceAndPath(
                DroingosDecor.MOD_ID,
                "block/" + name
        );
    }
}