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

# ---------------------------------------------------------------------------
# Roll back the temporary entity-based tiny decor system.
# ---------------------------------------------------------------------------

$FilesToRemove = @(
    "src/main/java/net/droingo/decor/entity/TinyDecorEntity.java",
    "src/main/java/net/droingo/decor/client/render/TinyDecorEntityRenderer.java"
)

foreach ($RelativePath in $FilesToRemove) {
    $FullPath = Join-Path $Root $RelativePath

    if (Test-Path -LiteralPath $FullPath) {
        Remove-Item -LiteralPath $FullPath -Force
    }
}

$EntitiesPath = Join-Path $Root "src/main/java/net/droingo/decor/registry/DecorEntities.java"

if (Test-Path -LiteralPath $EntitiesPath) {
    $EntitiesText = [System.IO.File]::ReadAllText($EntitiesPath)

    $EntitiesText = $EntitiesText.Replace(
        "import net.droingo.decor.entity.TinyDecorEntity;`r`n",
        ""
    )
    $EntitiesText = $EntitiesText.Replace(
        "import net.droingo.decor.entity.TinyDecorEntity;`n",
        ""
    )

    $TinyRegistrationPattern =
        '(?s)\s*public static final DeferredHolder<EntityType<\?>, EntityType<TinyDecorEntity>> TINY_DECOR\s*=\s*ENTITY_TYPES\.register\(.*?\);\s*(?=\s*private DecorEntities\(\))'

    $EntitiesText = [regex]::Replace(
        $EntitiesText,
        $TinyRegistrationPattern,
        "`r`n"
    )

    [System.IO.File]::WriteAllText(
        $EntitiesPath,
        $EntitiesText,
        $Utf8NoBom
    )
}

$ClientPath = Join-Path $Root "src/main/java/net/droingo/decor/client/DroingosDecorClient.java"

if (Test-Path -LiteralPath $ClientPath) {
    $ClientText = [System.IO.File]::ReadAllText($ClientPath)

    $ClientText = $ClientText.Replace(
        "import net.droingo.decor.client.render.TinyDecorEntityRenderer;`r`n",
        ""
    )
    $ClientText = $ClientText.Replace(
        "import net.droingo.decor.client.render.TinyDecorEntityRenderer;`n",
        ""
    )

    $RendererRegistrationPattern =
        '(?s)\s*event\.registerEntityRenderer\(\s*DecorEntities\.TINY_DECOR\.get\(\),\s*TinyDecorEntityRenderer::new\s*\);\s*'

    $ClientText = [regex]::Replace(
        $ClientText,
        $RendererRegistrationPattern,
        "`r`n"
    )

    [System.IO.File]::WriteAllText(
        $ClientPath,
        $ClientText,
        $Utf8NoBom
    )
}

# ---------------------------------------------------------------------------
# Restore TinyDecorItem using the block container, now with a 3x3 grid.
# ---------------------------------------------------------------------------

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
    public static final int SLOT_COUNT = 9;

    private final ResourceLocation decorId;

    public TinyDecorItem(
            String id,
            Properties properties
    ) {
        super(properties);

        decorId =
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
                context.getItemInHand()
                        .shrink(1);
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
            case FLOOR ->
                    clickedPos.below();

            case CEILING ->
                    clickedPos.above();

            case WALL ->
                    clickedPos.relative(
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
        int column =
                Math.min(
                        2,
                        (int) Math.floor(x * 3.0D)
                );

        int row =
                Math.min(
                        2,
                        (int) Math.floor(z * 3.0D)
                );

        return row * 3 + column;
    }

    public static double centreX(int slot) {
        int column = slot % 3;
        return (column + 0.5D) / 3.0D;
    }

    public static double centreZ(int slot) {
        int row = slot / 3;
        return (row + 0.5D) / 3.0D;
    }
}
'@

# ---------------------------------------------------------------------------
# Expand container storage from 4 slots to 9.
# Existing slots 0-3 remain compatible with old saves.
# ---------------------------------------------------------------------------

Write-Utf8NoBom "src/main/java/net/droingo/decor/content/DecorContainerBlockEntity.java" @'
package net.droingo.decor.content;

import net.droingo.decor.registry.DecorBlockEntities;
import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.Connection;
import net.minecraft.network.protocol.game.ClientboundBlockEntityDataPacket;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;

public final class DecorContainerBlockEntity extends BlockEntity {
    private final ResourceLocation[] ids =
            new ResourceLocation[TinyDecorItem.SLOT_COUNT];

    private final byte[] rotations =
            new byte[TinyDecorItem.SLOT_COUNT];

    public DecorContainerBlockEntity(
            BlockPos pos,
            BlockState state
    ) {
        super(
                DecorBlockEntities.DECOR_CONTAINER.get(),
                pos,
                state
        );
    }

    public boolean isEmpty(int slot) {
        return valid(slot) && ids[slot] == null;
    }

    public boolean isCompletelyEmpty() {
        for (ResourceLocation id : ids) {
            if (id != null) {
                return false;
            }
        }

        return true;
    }

    public ResourceLocation getDecorId(int slot) {
        return valid(slot) ? ids[slot] : null;
    }

    public int getRotation(int slot) {
        return valid(slot)
                ? Byte.toUnsignedInt(rotations[slot])
                : 0;
    }

    public boolean place(
            int slot,
            ResourceLocation id,
            int rotation
    ) {
        if (!valid(slot) || !isEmpty(slot)) {
            return false;
        }

        ids[slot] = id;
        rotations[slot] =
                (byte) (rotation & 15);

        sync();
        return true;
    }

    public ResourceLocation remove(int slot) {
        if (!valid(slot)) {
            return null;
        }

        ResourceLocation old = ids[slot];

        ids[slot] = null;
        rotations[slot] = 0;

        sync();
        return old;
    }

    public void rotate(int slot) {
        if (valid(slot) && ids[slot] != null) {
            rotations[slot] =
                    (byte) (
                            (
                                    rotations[slot]
                                            + 1
                            ) & 15
                    );

            sync();
        }
    }

    private boolean valid(int slot) {
        return slot >= 0
                && slot < TinyDecorItem.SLOT_COUNT;
    }

    private void sync() {
        setChanged();

        if (
                level != null
                        && !level.isClientSide
        ) {
            level.sendBlockUpdated(
                    worldPosition,
                    getBlockState(),
                    getBlockState(),
                    3
            );
        }
    }

    @Override
    protected void saveAdditional(
            CompoundTag tag,
            HolderLookup.Provider registries
    ) {
        super.saveAdditional(tag, registries);

        for (
                int i = 0;
                i < TinyDecorItem.SLOT_COUNT;
                i++
        ) {
            if (ids[i] != null) {
                tag.putString(
                        "Decor" + i,
                        ids[i].toString()
                );

                tag.putByte(
                        "Rot" + i,
                        rotations[i]
                );
            }
        }
    }

    @Override
    protected void loadAdditional(
            CompoundTag tag,
            HolderLookup.Provider registries
    ) {
        super.loadAdditional(tag, registries);

        for (
                int i = 0;
                i < TinyDecorItem.SLOT_COUNT;
                i++
        ) {
            ids[i] =
                    tag.contains("Decor" + i)
                            ? ResourceLocation.tryParse(
                            tag.getString(
                                    "Decor" + i
                            )
                    )
                            : null;

            rotations[i] =
                    tag.getByte("Rot" + i);
        }
    }

    @Override
    public CompoundTag getUpdateTag(
            HolderLookup.Provider registries
    ) {
        CompoundTag tag =
                super.getUpdateTag(registries);

        saveAdditional(tag, registries);
        return tag;
    }

    @Override
    public ClientboundBlockEntityDataPacket
    getUpdatePacket() {
        return ClientboundBlockEntityDataPacket
                .create(this);
    }

    @Override
    public void onDataPacket(
            Connection net,
            ClientboundBlockEntityDataPacket packet,
            HolderLookup.Provider registries
    ) {
        super.onDataPacket(
                net,
                packet,
                registries
        );
    }
}
'@

# ---------------------------------------------------------------------------
# Update render positions and motion arrays to 9 slots.
# ---------------------------------------------------------------------------

$RendererPath = Join-Path $Root "src/main/java/net/droingo/decor/client/render/DecorContainerRenderer.java"
$RendererText = [System.IO.File]::ReadAllText($RendererPath)

$RendererText = $RendererText.Replace(
    "for (int slot = 0; slot < 4; slot++)",
    "for (int slot = 0; slot < TinyDecorItem.SLOT_COUNT; slot++)"
)

if (-not $RendererText.Contains("import net.droingo.decor.content.TinyDecorItem;")) {
    $RendererText = $RendererText.Replace(
        "import net.droingo.decor.content.DecorContainerBlockEntity;",
        "import net.droingo.decor.content.DecorContainerBlockEntity;`r`nimport net.droingo.decor.content.TinyDecorItem;"
    )
}

$RendererText = [regex]::Replace(
    $RendererText,
    'double centreX\s*=\s*slot % 2 == 0 \? 0\.25D : 0\.75D;',
    'double centreX = TinyDecorItem.centreX(slot);'
)

$RendererText = [regex]::Replace(
    $RendererText,
    'double centreZ\s*=\s*slot < 2 \? 0\.25D : 0\.75D;',
    'double centreZ = TinyDecorItem.centreZ(slot);'
)

$RendererText = $RendererText.Replace(
    "new BobbleheadMotionState[4]",
    "new BobbleheadMotionState[TinyDecorItem.SLOT_COUNT]"
)

[System.IO.File]::WriteAllText(
    $RendererPath,
    $RendererText,
    $Utf8NoBom
)

# ---------------------------------------------------------------------------
# Update shapes to use 3x3 positions.
# ---------------------------------------------------------------------------

$ShapesPath = Join-Path $Root "src/main/java/net/droingo/decor/content/DecorShapes.java"
$ShapesText = [System.IO.File]::ReadAllText($ShapesPath)

$ShapesText = [regex]::Replace(
    $ShapesText,
    'double centreX\s*=\s*slot % 2 == 0 \? 0\.25D : 0\.75D;',
    'double centreX = TinyDecorItem.centreX(slot);'
)

$ShapesText = [regex]::Replace(
    $ShapesText,
    'double centreZ\s*=\s*slot < 2 \? 0\.25D : 0\.75D;',
    'double centreZ = TinyDecorItem.centreZ(slot);'
)

[System.IO.File]::WriteAllText(
    $ShapesPath,
    $ShapesText,
    $Utf8NoBom
)

# ---------------------------------------------------------------------------
# Update block hit loops and interaction pulse arrays.
# ---------------------------------------------------------------------------

$BlockPath = Join-Path $Root "src/main/java/net/droingo/decor/content/DecorContainerBlock.java"
$BlockText = [System.IO.File]::ReadAllText($BlockPath)

$BlockText = $BlockText.Replace(
    "for (int slot = 0; slot < 4; slot++)",
    "for (int slot = 0; slot < TinyDecorItem.SLOT_COUNT; slot++)"
)

[System.IO.File]::WriteAllText(
    $BlockPath,
    $BlockText,
    $Utf8NoBom
)

$PulsePath = Join-Path $Root "src/main/java/net/droingo/decor/client/animation/BobbleheadInteractionPulses.java"

if (Test-Path -LiteralPath $PulsePath) {
    $PulseText = [System.IO.File]::ReadAllText($PulsePath)

    if (-not $PulseText.Contains("import net.droingo.decor.content.TinyDecorItem;")) {
        $PulseText = $PulseText.Replace(
            "import net.droingo.decor.content.DecorContainerBlockEntity;",
            "import net.droingo.decor.content.DecorContainerBlockEntity;`r`nimport net.droingo.decor.content.TinyDecorItem;"
        )
    }

    $PulseText = $PulseText.Replace(
        "slot >= 4",
        "slot >= TinyDecorItem.SLOT_COUNT"
    )

    $PulseText = $PulseText.Replace(
        "new boolean[4]",
        "new boolean[TinyDecorItem.SLOT_COUNT]"
    )

    [System.IO.File]::WriteAllText(
        $PulsePath,
        $PulseText,
        $Utf8NoBom
    )
}

Write-Host ""
Write-Host "Rolled Tiny Decor back to block containers."
Write-Host "Expanded each container from 4 placements to a 3x3 grid of 9 placements."
Write-Host "Existing slots 0-3 remain compatible with old worlds."
Write-Host ""
Write-Host "Building..."
Write-Host ""

& ".\gradlew.bat" build

if ($LASTEXITCODE -ne 0) {
    throw "Build failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Build successful."
