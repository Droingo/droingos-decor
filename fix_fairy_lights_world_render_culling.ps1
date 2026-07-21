$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$src = Join-Path $root "src\main\java\net\droingo\decor"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backup = Join-Path $root "_fairy_world_renderer_backup_$timestamp"
$utf8 = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path $src)) {
    throw "Run this from the Droingos-Decor project root."
}

$targets = @(
    "client\render\FairyLightsTestRenderer.java",
    "client\render\FairyLightsWorldRenderer.java"
)

foreach ($relative in $targets) {
    $source = Join-Path $src $relative
    if (Test-Path $source) {
        $destination = Join-Path $backup $relative
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        Copy-Item $source $destination -Force
    }
}

function Write-Utf8 {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

$renderer = @'
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
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.item.DyeColor;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.phys.Vec3;
import net.neoforged.neoforge.client.model.data.ModelData;
import org.joml.Quaternionf;

import java.util.Collections;
import java.util.Set;
import java.util.WeakHashMap;

public final class FairyLightsTestRenderer
        implements BlockEntityRenderer<FairyLightsTestBlockEntity> {

    private static final ResourceLocation WIRE_MODEL =
            id("block/fairy_lights_wire");
    private static final ResourceLocation BULB_MODEL =
            id("block/fairy_lights_bulb");
    private static final ResourceLocation GLOW_MODEL =
            id("block/fairy_lights_glow");

    private static final int FULL_BRIGHT = 0x00F000F0;
    private static final double BULB_SPACING = 0.4D;

    /*
     * The normal block-entity renderer is used only to discover loaded
     * fairy-light anchors. Actual strings are drawn by the level-wide
     * FairyLightsWorldRenderer, so they are no longer culled with point A.
     */
    private static final Set<FairyLightsTestBlockEntity> TRACKED =
            Collections.newSetFromMap(new WeakHashMap<>());

    public FairyLightsTestRenderer(
            BlockEntityRendererProvider.Context context
    ) {
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
        synchronized (TRACKED) {
            TRACKED.add(blockEntity);
        }
    }

    static void renderTracked(
            PoseStack poseStack,
            MultiBufferSource buffers,
            float partialTick
    ) {
        Minecraft minecraft = Minecraft.getInstance();

        FairyLightsTestBlockEntity[] snapshot;
        synchronized (TRACKED) {
            TRACKED.removeIf(blockEntity ->
                    blockEntity == null
                            || blockEntity.isRemoved()
                            || blockEntity.getLevel() != minecraft.level
            );
            snapshot = TRACKED.toArray(
                    new FairyLightsTestBlockEntity[0]
            );
        }

        for (FairyLightsTestBlockEntity blockEntity : snapshot) {
            if (blockEntity.getLevel() != minecraft.level) {
                continue;
            }

            for (FairyLightsTestBlockEntity.Connection connection
                    : blockEntity.connections()) {
                renderConnection(
                        blockEntity,
                        connection,
                        connection.pointA(),
                        connection.pointB(),
                        partialTick,
                        poseStack,
                        buffers,
                        FULL_BRIGHT,
                        0
                );
            }
        }
    }

    private static void renderConnection(
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

    private static void renderWireSegment(
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

    private static void renderBulb(
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

    private static void renderModel(
            ResourceLocation location,
            PoseStack poseStack,
            MultiBufferSource buffers,
            float red,
            float green,
            float blue,
            int packedLight,
            int packedOverlay
    ) {
        Minecraft minecraft = Minecraft.getInstance();
        BlockRenderDispatcher blockRenderer =
                minecraft.getBlockRenderer();

        BakedModel model = minecraft
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
                int active = (int) (
                        (tick / 3L) % Math.max(1, count)
                );
                int distance = Math.floorMod(
                        index - active,
                        Math.max(1, count)
                );
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
    public boolean shouldRender(
            FairyLightsTestBlockEntity blockEntity,
            Vec3 cameraPosition
    ) {
        return true;
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
'@

$worldRenderer = @'
package net.droingo.decor.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import net.droingo.decor.DroingosDecor;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.world.phys.Vec3;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.client.event.RenderLevelStageEvent;

@EventBusSubscriber(
        modid = DroingosDecor.MOD_ID,
        value = Dist.CLIENT
)
public final class FairyLightsWorldRenderer {
    private FairyLightsWorldRenderer() {
    }

    @SubscribeEvent
    public static void renderLevel(RenderLevelStageEvent event) {
        if (event.getStage()
                != RenderLevelStageEvent.Stage.AFTER_CUTOUT_BLOCKS) {
            return;
        }

        Minecraft minecraft = Minecraft.getInstance();

        if (minecraft.level == null) {
            return;
        }

        Vec3 camera = event.getCamera().getPosition();
        PoseStack poseStack = event.getPoseStack();
        MultiBufferSource.BufferSource buffers =
                minecraft.renderBuffers().bufferSource();

        poseStack.pushPose();
        poseStack.translate(
                -camera.x,
                -camera.y,
                -camera.z
        );

        FairyLightsTestRenderer.renderTracked(
                poseStack,
                buffers,
                event.getPartialTick().getGameTimeDeltaPartialTick(false)
        );

        poseStack.popPose();
        buffers.endBatch(RenderType.cutout());
    }
}
'@

Write-Utf8 `
    (Join-Path $src "client\render\FairyLightsTestRenderer.java") `
    $renderer

Write-Utf8 `
    (Join-Path $src "client\render\FairyLightsWorldRenderer.java") `
    $worldRenderer

Write-Host ""
Write-Host "Installed level-wide fairy-light rendering." -ForegroundColor Green
Write-Host "Backup: $backup" -ForegroundColor Cyan
Write-Host ""
Write-Host "The source anchor now only registers the connection." -ForegroundColor Yellow
Write-Host "The string itself is rendered during the world render pass." -ForegroundColor Yellow
Write-Host ""
Write-Host "Now run: .\gradlew.bat compileJava" -ForegroundColor Yellow
