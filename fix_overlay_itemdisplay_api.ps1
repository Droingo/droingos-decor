$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$ProjectRoot = (Get-Location).Path
$BackupRoot = Join-Path $ProjectRoot (".overlay_api_fix_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))

function Backup-File {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $Target = Join-Path $ProjectRoot $RelativePath

    if (Test-Path -LiteralPath $Target) {
        $Backup = Join-Path $BackupRoot $RelativePath
        $BackupDirectory = Split-Path -Parent $Backup

        New-Item -ItemType Directory -Force -Path $BackupDirectory | Out-Null
        Copy-Item -LiteralPath $Target -Destination $Backup -Force
    }
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Content
    )

    Backup-File $RelativePath

    $Target = Join-Path $ProjectRoot $RelativePath
    $Directory = Split-Path -Parent $Target

    New-Item -ItemType Directory -Force -Path $Directory | Out-Null
    [System.IO.File]::WriteAllText($Target, $Content, $Utf8NoBom)
}

if (!(Test-Path -LiteralPath (Join-Path $ProjectRoot "build.gradle"))) {
    throw "Run this script from the Droingo's Decor project root."
}

Write-Host "Adding OVERLAY placement type..."

$PlacementRelative = "src/main/java/net/droingo/decor/api/DecorPlacementType.java"
$PlacementPath = Join-Path $ProjectRoot $PlacementRelative

if (!(Test-Path -LiteralPath $PlacementPath)) {
    throw "Missing: $PlacementPath"
}

$Placement = [System.IO.File]::ReadAllText($PlacementPath)

if ($Placement -notmatch '\bOVERLAY\b') {
    $Placement = [regex]::Replace(
        $Placement,
        '\bHANGING\b',
        'HANGING, OVERLAY',
        1
    )
}

Write-Utf8NoBom $PlacementRelative $Placement

Write-Host "Replacing OverlayItem.java with 1.21.1-compatible ItemDisplay setup..."

$OverlayItem = @'
package net.droingo.decor.content.overlay;

import net.droingo.decor.DroingosDecor;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.Display;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.context.UseOnContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.AABB;

import java.util.List;

/**
 * Proof-of-concept wall overlay.
 *
 * The visual is a vanilla ItemDisplay entity anchored to a supporting block
 * face. It occupies no block space, has no collision and therefore remains
 * when fences, torches, pipes or other partial blocks are placed in front.
 */
public final class OverlayItem extends Item {
    public static final String OVERLAY_MARKER =
            DroingosDecor.MOD_ID + "_overlay";

    public static final String SUPPORT_X =
            DroingosDecor.MOD_ID + "_overlay_support_x";

    public static final String SUPPORT_Y =
            DroingosDecor.MOD_ID + "_overlay_support_y";

    public static final String SUPPORT_Z =
            DroingosDecor.MOD_ID + "_overlay_support_z";

    public static final String SUPPORT_FACE =
            DroingosDecor.MOD_ID + "_overlay_support_face";

    public static final String OVERLAY_ID =
            DroingosDecor.MOD_ID + "_overlay_id";

    private static final double FACE_OFFSET = 0.5015D;

    private final ResourceLocation overlayId;

    public OverlayItem(String id, Properties properties) {
        super(properties);

        overlayId = ResourceLocation.fromNamespaceAndPath(
                DroingosDecor.MOD_ID,
                id
        );
    }

    @Override
    public InteractionResult useOn(UseOnContext context) {
        Direction face = context.getClickedFace();

        if (!face.getAxis().isHorizontal()) {
            return InteractionResult.PASS;
        }

        Level level = context.getLevel();
        BlockPos supportPos = context.getClickedPos();

        if (level.getBlockState(supportPos).isAir()) {
            return InteractionResult.FAIL;
        }

        if (level.isClientSide) {
            return InteractionResult.SUCCESS;
        }

        ServerLevel serverLevel = (ServerLevel) level;

        removeExistingOverlay(
                serverLevel,
                supportPos,
                face
        );

        Display.ItemDisplay display =
                EntityType.ITEM_DISPLAY.create(serverLevel);

        if (display == null) {
            return InteractionResult.FAIL;
        }

        double x =
                supportPos.getX()
                        + 0.5D
                        + face.getStepX() * FACE_OFFSET;

        double y =
                supportPos.getY() + 0.5D;

        double z =
                supportPos.getZ()
                        + 0.5D
                        + face.getStepZ() * FACE_OFFSET;

        display.setPos(x, y, z);
        display.setYRot(yawForFace(face));
        display.setXRot(0.0F);
        display.setNoGravity(true);

        /*
         * In 1.21.1 the direct ItemDisplay setters are private.
         * Slot 0 is the public vanilla inventory bridge for the displayed item.
         */
        display.getSlot(0).set(new ItemStack(this));

        /*
         * Preserve the entity's current data, then request FIXED item display
         * context through the vanilla saved-data field.
         */
        CompoundTag displayTag = new CompoundTag();
        display.saveWithoutId(displayTag);
        displayTag.putString("item_display", "fixed");
        display.load(displayTag);

        CompoundTag persistentData =
                display.getPersistentData();

        persistentData.putBoolean(OVERLAY_MARKER, true);
        persistentData.putInt(SUPPORT_X, supportPos.getX());
        persistentData.putInt(SUPPORT_Y, supportPos.getY());
        persistentData.putInt(SUPPORT_Z, supportPos.getZ());
        persistentData.putString(
                SUPPORT_FACE,
                face.getName()
        );
        persistentData.putString(
                OVERLAY_ID,
                overlayId.toString()
        );

        serverLevel.addFreshEntity(display);

        if (
                context.getPlayer() == null
                        || !context.getPlayer()
                        .getAbilities()
                        .instabuild
        ) {
            context.getItemInHand().shrink(1);
        }

        return InteractionResult.CONSUME;
    }

    public static void removeExistingOverlay(
            ServerLevel level,
            BlockPos supportPos,
            Direction face
    ) {
        AABB searchBox = new AABB(supportPos).inflate(1.1D);

        List<Display.ItemDisplay> displays =
                level.getEntitiesOfClass(
                        Display.ItemDisplay.class,
                        searchBox,
                        display -> isOverlayFor(
                                display,
                                supportPos,
                                face
                        )
                );

        for (Display.ItemDisplay display : displays) {
            display.discard();
        }
    }

    public static boolean isOverlayFor(
            Display.ItemDisplay display,
            BlockPos supportPos,
            Direction face
    ) {
        CompoundTag data = display.getPersistentData();

        if (!data.getBoolean(OVERLAY_MARKER)) {
            return false;
        }

        return data.getInt(SUPPORT_X) == supportPos.getX()
                && data.getInt(SUPPORT_Y) == supportPos.getY()
                && data.getInt(SUPPORT_Z) == supportPos.getZ()
                && data.getString(SUPPORT_FACE)
                .equals(face.getName());
    }

    public static boolean isOverlay(
            Display.ItemDisplay display
    ) {
        return display.getPersistentData()
                .getBoolean(OVERLAY_MARKER);
    }

    public static BlockPos getSupportPos(
            Display.ItemDisplay display
    ) {
        CompoundTag data = display.getPersistentData();

        return new BlockPos(
                data.getInt(SUPPORT_X),
                data.getInt(SUPPORT_Y),
                data.getInt(SUPPORT_Z)
        );
    }

    private static float yawForFace(Direction face) {
        return switch (face) {
            case SOUTH -> 0.0F;
            case WEST -> 90.0F;
            case NORTH -> 180.0F;
            case EAST -> -90.0F;
            default -> 0.0F;
        };
    }
}
'@

Write-Utf8NoBom `
    "src/main/java/net/droingo/decor/content/overlay/OverlayItem.java" `
    $OverlayItem

Write-Host ""
Write-Host "Overlay API compatibility fix installed."
Write-Host "Backup directory: $BackupRoot"
Write-Host ""
Write-Host "Building..."
Write-Host ""

& .\gradlew.bat build

if ($LASTEXITCODE -ne 0) {
    throw "Build still failed. Send the new compile output. Backup: $BackupRoot"
}

Write-Host ""
Write-Host "Build successful."
