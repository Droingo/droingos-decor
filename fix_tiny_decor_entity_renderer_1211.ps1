$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Root = (Get-Location).Path

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $FullPath = Join-Path $Root $Path
    $Directory = Split-Path -Parent $FullPath

    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    }

    [System.IO.File]::WriteAllText($FullPath, $Content, $Utf8NoBom)
}

Write-Utf8NoBom "src/main/java/net/droingo/decor/client/render/TinyDecorEntityRenderer.java" @'
package net.droingo.decor.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;
import dev.ryanhcode.sable.Sable;
import net.droingo.decor.api.BobbleheadRenderDefinition;
import net.droingo.decor.api.DecorDefinition;
import net.droingo.decor.client.animation.BobbleheadMotionState;
import net.droingo.decor.entity.TinyDecorEntity;
import net.droingo.decor.registry.DecorDefinitionRegistry;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.block.BlockRenderDispatcher;
import net.minecraft.client.renderer.entity.EntityRenderer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.resources.model.BakedModel;
import net.minecraft.client.resources.model.ModelResourceLocation;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.phys.Vec3;
import net.neoforged.neoforge.client.model.data.ModelData;
import org.joml.Vector3d;

import java.util.Map;
import java.util.WeakHashMap;

public final class TinyDecorEntityRenderer
        extends EntityRenderer<TinyDecorEntity> {

    private static final ResourceLocation TEXTURE =
            ResourceLocation.withDefaultNamespace(
                    "textures/misc/white.png"
            );

    private final BlockRenderDispatcher blockRenderer;

    private final Map<
            TinyDecorEntity,
            BobbleheadMotionState
            > motionStates = new WeakHashMap<>();

    private final Map<
            TinyDecorEntity,
            Integer
            > pulseCounters = new WeakHashMap<>();

    public TinyDecorEntityRenderer(
            EntityRendererProvider.Context context
    ) {
        super(context);

        blockRenderer =
                Minecraft.getInstance()
                        .getBlockRenderer();
    }

    @Override
    public void render(
            TinyDecorEntity entity,
            float entityYaw,
            float partialTick,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight
    ) {
        ResourceLocation id =
                entity.getDecorId();

        DecorDefinition definition =
                id == null
                        ? null
                        : DecorDefinitionRegistry.get(id);

        if (
                definition == null
                        || definition.bobbleheadRender()
                        == null
        ) {
            return;
        }

        BobbleheadRenderDefinition render =
                definition.bobbleheadRender();

        BobbleheadMotionState motion =
                motionStates.computeIfAbsent(
                        entity,
                        ignored ->
                                new BobbleheadMotionState()
                );

        int pulse =
                entity.getPulseCounter();

        Integer previous =
                pulseCounters.put(entity, pulse);

        if (
                previous != null
                        && pulse != previous
        ) {
            motion.addInteractionImpulse();
        }

        float yaw =
                entity.getRotationStep()
                        * 22.5F;

        updateMotion(
                entity,
                motion,
                yaw,
                render.pivot().y,
                partialTick
        );

        poseStack.pushPose();

        poseStack.mulPose(
                Axis.YP.rotationDegrees(yaw)
        );

        poseStack.scale(
                render.scale(),
                render.scale(),
                render.scale()
        );

        poseStack.translate(
                -0.5D,
                0.0D,
                -0.5D
        );

        renderModel(
                poseStack,
                buffers,
                render.bodyModel(),
                packedLight
        );

        Vector3d pivot =
                render.pivot();

        poseStack.pushPose();

        poseStack.translate(
                pivot.x,
                pivot.y,
                pivot.z
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
                -pivot.x,
                -pivot.y,
                -pivot.z
        );

        renderModel(
                poseStack,
                buffers,
                render.movingModel(),
                packedLight
        );

        poseStack.popPose();
        poseStack.popPose();

        super.render(
                entity,
                entityYaw,
                partialTick,
                poseStack,
                buffers,
                packedLight
        );
    }

    private static void updateMotion(
            TinyDecorEntity entity,
            BobbleheadMotionState motion,
            float yawDegrees,
            double pivotY,
            float partialTick
    ) {
        Vec3 localOrigin =
                new Vec3(
                        entity.getX(),
                        entity.getY() + pivotY,
                        entity.getZ()
                );

        Vec3 worldOrigin =
                Sable.HELPER.projectOutOfSubLevel(
                        entity.level(),
                        localOrigin
                );

        Vec3 worldX =
                Sable.HELPER.projectOutOfSubLevel(
                        entity.level(),
                        localOrigin.add(
                                1.0D,
                                0.0D,
                                0.0D
                        )
                ).subtract(worldOrigin);

        Vec3 worldZ =
                Sable.HELPER.projectOutOfSubLevel(
                        entity.level(),
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

        double yawRadians =
                Math.toRadians(yawDegrees);

        double cos =
                Math.cos(yawRadians);

        double sin =
                Math.sin(yawRadians);

        Vec3 right =
                worldX.scale(cos)
                        .add(
                                worldZ.scale(sin)
                        )
                        .normalize();

        Vec3 forward =
                worldX.scale(sin)
                        .add(
                                worldZ.scale(-cos)
                        )
                        .normalize();

        motion.update(
                entity.level().getGameTime()
                        + partialTick,
                worldOrigin,
                right,
                forward
        );
    }

    private void renderModel(
            PoseStack poseStack,
            MultiBufferSource buffers,
            ResourceLocation location,
            int light
    ) {
        BakedModel model =
                Minecraft.getInstance()
                        .getModelManager()
                        .getModel(
                                ModelResourceLocation
                                        .standalone(location)
                        );

        VertexConsumer consumer =
                buffers.getBuffer(
                        RenderType.cutout()
                );

        blockRenderer.getModelRenderer()
                .renderModel(
                        poseStack.last(),
                        consumer,
                        Blocks.AIR
                                .defaultBlockState(),
                        model,
                        1.0F,
                        1.0F,
                        1.0F,
                        light,
                        net.minecraft.client.renderer
                                .texture.OverlayTexture
                                .NO_OVERLAY,
                        ModelData.EMPTY,
                        RenderType.cutout()
                );
    }

    @Override
    public ResourceLocation getTextureLocation(
            TinyDecorEntity entity
    ) {
        return TEXTURE;
    }
}
'@

$EntityPath = Join-Path $Root "src/main/java/net/droingo/decor/entity/TinyDecorEntity.java"

if (-not (Test-Path -LiteralPath $EntityPath)) {
    throw "Could not find TinyDecorEntity.java. Run this from the project root after the conversion installer."
}

$EntityText = [System.IO.File]::ReadAllText($EntityPath)

$UnsupportedMethod = '(?s)\s*@Override\s+public boolean canBeCollidedWith\(\)\s*\{\s*return false;\s*\}\s*'
$EntityText = [regex]::Replace(
        $EntityText,
        $UnsupportedMethod,
        "`r`n"
)

[System.IO.File]::WriteAllText(
        $EntityPath,
        $EntityText,
        $Utf8NoBom
)

$ClientPath = Join-Path $Root "src/main/java/net/droingo/decor/client/DroingosDecorClient.java"
$ClientText = [System.IO.File]::ReadAllText($ClientPath)

$ClientText = $ClientText.Replace(
        ");        event.registerEntityRenderer(",
        ");`r`n        event.registerEntityRenderer("
)

[System.IO.File]::WriteAllText(
        $ClientPath,
        $ClientText,
        $Utf8NoBom
)

Write-Host ""
Write-Host "Repaired Tiny Decor for the project's Minecraft 1.21.1 renderer API."
Write-Host "Building..."
Write-Host ""

& ".\gradlew.bat" build

if ($LASTEXITCODE -ne 0) {
    throw "Build failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Build successful."
