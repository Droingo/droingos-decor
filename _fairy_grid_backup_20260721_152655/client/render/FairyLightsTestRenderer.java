package net.droingo.decor.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import net.droingo.decor.DroingosDecor;
import net.droingo.decor.content.FairyLightsMode;
import net.droingo.decor.content.FairyLightsTestBlockEntity;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.block.BlockRenderDispatcher;
import net.minecraft.client.renderer.blockentity.BlockEntityRenderer;
import net.minecraft.client.renderer.blockentity.BlockEntityRendererProvider;
import net.minecraft.client.resources.model.BakedModel;
import net.minecraft.client.resources.model.ModelResourceLocation;
import net.minecraft.core.BlockPos;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.item.DyeColor;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.phys.Vec3;
import net.neoforged.neoforge.client.model.data.ModelData;
import org.joml.Quaternionf;

public final class FairyLightsTestRenderer
        implements BlockEntityRenderer<FairyLightsTestBlockEntity> {

    private static final ResourceLocation WIRE_MODEL =
            id("block/fairy_lights_wire");
    private static final ResourceLocation BULB_MODEL =
            id("block/fairy_lights_bulb");
    private static final ResourceLocation GLOW_MODEL =
            id("block/fairy_lights_glow");

    private static final int FULL_BRIGHT = 0x00F000F0;
    private static final double BULB_SPACING = 0.5D;

    private final BlockRenderDispatcher blockRenderer;

    public FairyLightsTestRenderer(
            BlockEntityRendererProvider.Context context
    ) {
        blockRenderer = context.getBlockRenderDispatcher();
    }

    @Override
    public void render(
            FairyLightsTestBlockEntity blockEntity,
            float partialTick,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        BlockPos origin = blockEntity.getBlockPos();

        for (FairyLightsTestBlockEntity.Connection connection
                : blockEntity.connections()) {
            Vec3 start = connection.pointA().subtract(
                    origin.getX(),
                    origin.getY(),
                    origin.getZ()
            );
            Vec3 end = connection.pointB().subtract(
                    origin.getX(),
                    origin.getY(),
                    origin.getZ()
            );

            renderConnection(
                    blockEntity,
                    connection,
                    start,
                    end,
                    partialTick,
                    poseStack,
                    buffers,
                    packedLight,
                    packedOverlay
            );
        }
    }

    private void renderConnection(
            FairyLightsTestBlockEntity blockEntity,
            FairyLightsTestBlockEntity.Connection connection,
            Vec3 start,
            Vec3 end,
            float partialTick,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        double directDistance = start.distanceTo(end);
        int wireSegments = Math.max(
                8,
                Math.min(128, (int) Math.ceil(directDistance * 8.0D))
        );

        for (int index = 0; index < wireSegments; index++) {
            double t0 = index / (double) wireSegments;
            double t1 = (index + 1) / (double) wireSegments;
            Vec3 p0 = curve(start, end, t0, connection.sag());
            Vec3 p1 = curve(start, end, t1, connection.sag());
            renderWireSegment(
                    p0,
                    p1,
                    poseStack,
                    buffers,
                    packedLight,
                    packedOverlay
            );
        }

        int bulbCount = Math.max(
                2,
                (int) Math.floor(directDistance / BULB_SPACING) + 1
        );

        long gameTime = blockEntity.getLevel() == null
                ? 0L
                : blockEntity.getLevel().getGameTime();

        float[] color = rgb(connection.color());

        for (int index = 0; index < bulbCount; index++) {
            double t = bulbCount == 1
                    ? 0.5D
                    : index / (double) (bulbCount - 1);

            Vec3 position = curve(
                    start,
                    end,
                    t,
                    connection.sag()
            );

            renderBulb(
                    position,
                    false,
                    color,
                    poseStack,
                    buffers,
                    packedLight,
                    packedOverlay
            );

            if (isLit(
                    connection.mode(),
                    index,
                    bulbCount,
                    gameTime,
                    partialTick
            )) {
                renderBulb(
                        position,
                        true,
                        color,
                        poseStack,
                        buffers,
                        FULL_BRIGHT,
                        packedOverlay
                );
            }
        }
    }

    private void renderWireSegment(
            Vec3 start,
            Vec3 end,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        Vec3 delta = end.subtract(start);
        double length = delta.length();
        if (length < 0.0001D) {
            return;
        }

        Vec3 direction = delta.scale(1.0D / length);

        poseStack.pushPose();
        poseStack.translate(start.x, start.y, start.z);
        poseStack.mulPose(
                new Quaternionf().rotationTo(
                        0.0F,
                        0.0F,
                        1.0F,
                        (float) direction.x,
                        (float) direction.y,
                        (float) direction.z
                )
        );
        poseStack.scale(1.0F, 1.0F, (float) length);
        poseStack.translate(-0.5D, -7.25D / 16.0D, 0.0D);

        renderModel(
                WIRE_MODEL,
                poseStack,
                buffers,
                1.0F,
                1.0F,
                1.0F,
                packedLight,
                packedOverlay
        );
        poseStack.popPose();
    }

    private void renderBulb(
            Vec3 position,
            boolean glow,
            float[] color,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        poseStack.pushPose();
        poseStack.translate(position.x, position.y, position.z);
        poseStack.translate(-0.5D, -7.0D / 16.0D, -0.5D);

        renderModel(
                glow ? GLOW_MODEL : BULB_MODEL,
                poseStack,
                buffers,
                color[0],
                color[1],
                color[2],
                packedLight,
                packedOverlay
        );
        poseStack.popPose();
    }

    private void renderModel(
            ResourceLocation location,
            PoseStack poseStack,
            MultiBufferSource buffers,
            float red,
            float green,
            float blue,
            int packedLight,
            int packedOverlay
    ) {
        BakedModel model = Minecraft.getInstance()
                .getModelManager()
                .getModel(ModelResourceLocation.standalone(location));

        RenderType renderType = RenderType.cutout();
        VertexConsumer consumer = buffers.getBuffer(renderType);

        blockRenderer.getModelRenderer().renderModel(
                poseStack.last(),
                consumer,
                Blocks.AIR.defaultBlockState(),
                model,
                red,
                green,
                blue,
                packedLight,
                packedOverlay,
                ModelData.EMPTY,
                renderType
        );
    }

    public static Vec3 curve(
            Vec3 start,
            Vec3 end,
            double t,
            double sagFactor
    ) {
        Vec3 linear = start.lerp(end, t);
        double distance = start.distanceTo(end);
        double sag = distance
                * sagFactor
                * 4.0D
                * t
                * (1.0D - t);

        return linear.add(0.0D, -sag, 0.0D);
    }

    private static boolean isLit(
            FairyLightsMode mode,
            int index,
            int count,
            long gameTime,
            float partialTick
    ) {
        long tick = gameTime;
        return switch (mode) {
            case STEADY -> true;
            case OFF -> false;
            case ALTERNATING ->
                    ((index & 1) == ((tick / 10L) & 1L));
            case CHASE -> {
                int active = (int) ((tick / 3L) % Math.max(1, count));
                int distance = Math.floorMod(index - active, Math.max(1, count));
                yield distance <= 2;
            }
            case TWINKLE -> {
                long seed = index * 341873128712L;
                long phase = Math.floorMod(seed, 37L);
                yield Math.floorMod(tick + phase, 37L) < 18L;
            }
            case PULSE ->
                    Math.floorMod(tick, 40L) < 24L;
        };
    }

    private static float[] rgb(DyeColor color) {
        return switch (color) {
            case WHITE -> new float[]{1.00F, 1.00F, 1.00F};
            case ORANGE -> new float[]{1.00F, 0.50F, 0.12F};
            case MAGENTA -> new float[]{0.78F, 0.25F, 0.78F};
            case LIGHT_BLUE -> new float[]{0.35F, 0.70F, 1.00F};
            case YELLOW -> new float[]{1.00F, 0.88F, 0.20F};
            case LIME -> new float[]{0.50F, 0.90F, 0.18F};
            case PINK -> new float[]{1.00F, 0.45F, 0.67F};
            case GRAY -> new float[]{0.35F, 0.35F, 0.35F};
            case LIGHT_GRAY -> new float[]{0.68F, 0.68F, 0.68F};
            case CYAN -> new float[]{0.15F, 0.65F, 0.70F};
            case PURPLE -> new float[]{0.50F, 0.20F, 0.70F};
            case BLUE -> new float[]{0.18F, 0.28F, 0.80F};
            case BROWN -> new float[]{0.45F, 0.28F, 0.15F};
            case GREEN -> new float[]{0.20F, 0.55F, 0.18F};
            case RED -> new float[]{0.85F, 0.16F, 0.14F};
            case BLACK -> new float[]{0.12F, 0.12F, 0.12F};
        };
    }

    @Override
    public boolean shouldRenderOffScreen(
            FairyLightsTestBlockEntity blockEntity
    ) {
        return true;
    }

    @Override
    public int getViewDistance() {
        return 128;
    }

    private static ResourceLocation id(String path) {
        return ResourceLocation.fromNamespaceAndPath(
                DroingosDecor.MOD_ID,
                path
        );
    }
}