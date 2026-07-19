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

Write-Utf8NoBom "src/main/java/net/droingo/decor/content/TinyDecorItem.java" @'
package net.droingo.decor.content;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.registry.DecorBlocks;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.util.Mth;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.context.UseOnContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.properties.AttachFace;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;

public final class TinyDecorItem extends Item {
    private final ResourceLocation decorId;

    public TinyDecorItem(
            String id,
            Properties properties
    ) {
        super(properties);

        this.decorId =
                ResourceLocation.fromNamespaceAndPath(
                        DroingosDecor.MOD_ID,
                        id
                );
    }

    @Override
    public InteractionResult useOn(
            UseOnContext context
    ) {
        Level level = context.getLevel();

        BlockPos clickedPos =
                context.getClickedPos();

        BlockState clickedState =
                level.getBlockState(clickedPos);

        /*
         * Levers and buttons occupy the neighbouring air block rather than
         * the solid block they are attached to. Redirect placement back to
         * their support block so a bobblehead can still be placed on top of
         * that block.
         */
        BlockPos supportPos =
                resolveSupportBlock(
                        clickedPos,
                        clickedState
                );

        boolean clickedAttachment =
                !supportPos.equals(clickedPos);

        if (
                !clickedAttachment
                        && context.getClickedFace()
                        != Direction.UP
        ) {
            return InteractionResult.PASS;
        }

        BlockPos pos;

        if (
                level.getBlockState(clickedPos)
                        .is(
                                DecorBlocks
                                        .DECOR_CONTAINER
                                        .get()
                        )
        ) {
            pos = clickedPos;
        } else {
            pos = supportPos.above();
        }

        BlockState state =
                level.getBlockState(pos);

        if (
                !state.isAir()
                        && !state.is(
                        DecorBlocks
                                .DECOR_CONTAINER
                                .get()
                )
        ) {
            return InteractionResult.FAIL;
        }

        double x =
                context.getClickLocation().x
                        - supportPos.getX();

        double z =
                context.getClickLocation().z
                        - supportPos.getZ();

        x = Mth.clamp(x, 0.0D, 0.999999D);
        z = Mth.clamp(z, 0.0D, 0.999999D);

        int slot = slotFromHit(x, z);

        int rotation =
                Mth.floor(
                        (
                                context.getRotation()
                                        + 11.25F
                        ) / 22.5F
                ) & 15;

        if (!level.isClientSide) {
            if (state.isAir()) {
                level.setBlock(
                        pos,
                        DecorBlocks
                                .DECOR_CONTAINER
                                .get()
                                .defaultBlockState(),
                        3
                );

                DecorPlacementSounds.play(
                        level,
                        pos,
                        context.getPlayer()
                );
            }

            if (
                    !(level.getBlockEntity(pos)
                            instanceof DecorContainerBlockEntity be)
                            || !be.place(
                            slot,
                            decorId,
                            rotation
                    )
            ) {
                return InteractionResult.FAIL;
            }

            if (
                    context.getPlayer() == null
                            || !context.getPlayer()
                            .getAbilities()
                            .instabuild
            ) {
                context.getItemInHand().shrink(1);
            }
        }

        return InteractionResult.sidedSuccess(
                level.isClientSide
        );
    }

    private static BlockPos resolveSupportBlock(
            BlockPos clickedPos,
            BlockState state
    ) {
        if (
                !state.hasProperty(
                        BlockStateProperties.ATTACH_FACE
                )
                        || !state.hasProperty(
                        BlockStateProperties
                                .HORIZONTAL_FACING
                )
        ) {
            return clickedPos;
        }

        AttachFace attachFace =
                state.getValue(
                        BlockStateProperties.ATTACH_FACE
                );

        return switch (attachFace) {
            case FLOOR -> clickedPos.below();
            case CEILING -> clickedPos.above();
            case WALL -> clickedPos.relative(
                    state.getValue(
                                    BlockStateProperties
                                            .HORIZONTAL_FACING
                            )
                            .getOpposite()
            );
        };
    }

    public static int slotFromHit(
            double x,
            double z
    ) {
        return (
                z >= 0.5D
                        ? 2
                        : 0
        ) + (
                x >= 0.5D
                        ? 1
                        : 0
        );
    }
}
'@

Write-Host ""
Write-Host "Updated bobblehead placement to work through attached levers and buttons."
Write-Host "Building..."
Write-Host ""

& ".\gradlew.bat" build

if ($LASTEXITCODE -ne 0) {
    throw "Build failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Build successful."
