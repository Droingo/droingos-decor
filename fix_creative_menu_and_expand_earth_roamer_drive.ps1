$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Root = (Get-Location).Path
$BackupRoot = Join-Path $Root (".earth_roamer_menu_drive_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))

function Backup-File {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $Target = Join-Path $Root $RelativePath

    if (Test-Path -LiteralPath $Target) {
        $Backup = Join-Path $BackupRoot $RelativePath
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Backup) | Out-Null
        Copy-Item -LiteralPath $Target -Destination $Backup -Force
    }
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Content
    )

    Backup-File $RelativePath

    $Target = Join-Path $Root $RelativePath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Target) | Out-Null
    [System.IO.File]::WriteAllText($Target, $Content, $Utf8NoBom)
}

if (!(Test-Path -LiteralPath (Join-Path $Root "build.gradle"))) {
    throw "Run this script from the Droingo's Decor project root."
}

# ---------------------------------------------------------------------------
# Creative menu repair
#
# Your existing tab layout relies on real marker items so the overlay renderer
# can detect each category row. The menu broke only because those marker items
# had no item models. Give every marker the same fully transparent model.
# ---------------------------------------------------------------------------

$TexturePath = Join-Path $Root "src/main/resources/assets/droingos_decor/textures/item/creative_layout_marker.png"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $TexturePath) | Out-Null

[System.IO.File]::WriteAllBytes(
        $TexturePath,
        [Convert]::FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=")
)

$MarkerModel = @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@

$ModelDirectory = Join-Path $Root "src/main/resources/assets/droingos_decor/models/item"
New-Item -ItemType Directory -Force -Path $ModelDirectory | Out-Null

for ($Index = 0; $Index -lt 64; $Index++) {
    $Relative = "src/main/resources/assets/droingos_decor/models/item/creative_spacer_$Index.json"
    Write-Utf8NoBom $Relative $MarkerModel
}

$Categories = @(
    "bobbleheads",
    "half_blocks",
    "wall_decor",
    "hanging_decor",
    "small_decor",
    "furniture",
    "lighting",
    "outdoor_decor",
    "overlays"
)

foreach ($Category in $Categories) {
    for ($Index = 0; $Index -lt 9; $Index++) {
        $Relative = "src/main/resources/assets/droingos_decor/models/item/creative_header_${Category}_$Index.json"
        Write-Utf8NoBom $Relative $MarkerModel
    }
}

# ---------------------------------------------------------------------------
# Earth Roamer animation
# ---------------------------------------------------------------------------

Write-Utf8NoBom `
    "src/main/java/net/droingo/decor/client/render/HalfDecorRenderer.java" `
@'
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
import net.minecraft.util.Mth;
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

    /*
     * About 2.7 seconds at normal speed.
     */
    private static final double ANIMATION_LENGTH_TICKS = 54.0D;

    /*
     * The toy drives one small complete circle and returns to the exact
     * position and facing it started with.
     */
    private static final double DRIVE_RADIUS = 2.25D / 16.0D;
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
        double progress = animationProgress(
                blockEntity,
                partialTick
        );

        /*
         * Smoothstep gives the toy a gentle hand-pushed start and stop.
         */
        double easedProgress =
                progress * progress
                        * (3.0D - 2.0D * progress);

        double angle =
                easedProgress * Math.PI * 2.0D;

        /*
         * A circle whose starting point is the block centre. The circle's
         * centre is to the toy's right, so it begins by driving forward.
         */
        double driveX =
                DRIVE_RADIUS
                        * (1.0D - Math.cos(angle));

        double driveZ =
                -DRIVE_RADIUS
                        * Math.sin(angle);

        /*
         * Tangent direction for the circular route. Zero at the start and end,
         * increasing smoothly through one complete turn.
         */
        float driveYaw =
                (float) Math.toDegrees(angle);

        /*
         * Arc length determines wheel roll, so the wheels match the travelled
         * distance even while the body is turning.
         */
        double travelledDistance =
                DRIVE_RADIUS * angle;

        double wheelDegrees =
                Math.toDegrees(
                        travelledDistance
                                / WHEEL_RADIUS
                );

        float placedYaw =
                blockEntity.getRotation() * 22.5F;

        poseStack.pushPose();

        poseStack.translate(
                0.5D,
                0.03125D,
                0.5D
        );

        poseStack.mulPose(
                Axis.YP.rotationDegrees(placedYaw)
        );

        poseStack.translate(
                driveX,
                0.0D,
                driveZ
        );

        poseStack.mulPose(
                Axis.YP.rotationDegrees(driveYaw)
        );

        poseStack.translate(
                -0.5D,
                0.0D,
                -0.5D
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

        return Mth.clamp(
                elapsed / ANIMATION_LENGTH_TICKS,
                0.0D,
                1.0D
        );
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

        poseStack.translate(
                pivotX,
                pivotY,
                pivotZ
        );

        poseStack.mulPose(
                Axis.XP.rotationDegrees(
                        (float) -wheelDegrees
                )
        );

        poseStack.translate(
                -pivotX,
                -pivotY,
                -pivotZ
        );

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

    private static ResourceLocation model(String name) {
        return ResourceLocation.fromNamespaceAndPath(
                DroingosDecor.MOD_ID,
                "block/" + name
        );
    }
}

'@

Write-Host ""
Write-Host "Repaired creative layout-marker models."
Write-Host "Changed Earth Roamer to a small circular drive animation."
Write-Host "Backup directory: $BackupRoot"
Write-Host ""
Write-Host "Building..."
Write-Host ""

& .\gradlew.bat build

if ($LASTEXITCODE -ne 0) {
    throw "Build failed. Send the compile output. Backup: $BackupRoot"
}

Write-Host ""
Write-Host "Build successful."
Write-Host ""
Write-Host "Test:"
Write-Host "  1. Creative category rows are blank behind the drawn banners."
Write-Host "  2. Half Blocks appears between Bobbleheads and Wall Decor."
Write-Host "  3. Right-clicking Earth Roamer drives one small circle and returns."
