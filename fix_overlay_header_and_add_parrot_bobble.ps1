$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Root = (Get-Location).Path
$BackupRoot = Join-Path $Root (".overlay_and_parrot_bobble_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))

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

function Replace-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$OldText,
        [Parameter(Mandatory = $true)][string]$NewText,
        [Parameter(Mandatory = $true)][string]$Description
    )

    $Target = Join-Path $Root $RelativePath

    if (!(Test-Path -LiteralPath $Target)) {
        throw "Missing file: $RelativePath"
    }

    $Text = [System.IO.File]::ReadAllText($Target)

    if (!$Text.Contains($OldText)) {
        throw "Could not find expected code for: $Description"
    }

    Backup-File $RelativePath
    $Text = $Text.Replace($OldText, $NewText)
    [System.IO.File]::WriteAllText($Target, $Text, $Utf8NoBom)
}

if (!(Test-Path -LiteralPath (Join-Path $Root "build.gradle"))) {
    throw "Run this script from the Droingo's Decor project root."
}

# ---------------------------------------------------------------------------
# 1) Give every padding position a unique spacer item.
#
# Reusing the same eight spacer items causes NeoForge's creative tab output to
# deduplicate later padding rows. That is why the Overlays banner slides into
# the same row as the sweater.
# ---------------------------------------------------------------------------

Replace-Checked `
    "src/main/java/net/droingo/decor/registry/DecorItems.java" `
@'
        List<DeferredItem<Item>> spacers = new ArrayList<>(8);

        for (int index = 0; index < 8; index++) {
'@ `
@'
        List<DeferredItem<Item>> spacers = new ArrayList<>(64);

        for (int index = 0; index < 64; index++) {
'@ `
    "expand the unique creative spacer pool"

Write-Utf8NoBom `
    "src/main/java/net/droingo/decor/registry/DecorCreativeTabs.java" `
@'
package net.droingo.decor.registry;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.api.DecorCategory;
import net.droingo.decor.api.DecorDefinition;
import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.CreativeModeTab;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforge.registries.DeferredHolder;
import net.neoforged.neoforge.registries.DeferredItem;
import net.neoforged.neoforge.registries.DeferredRegister;

import java.util.List;

public final class DecorCreativeTabs {
    private static final int CREATIVE_ROW_WIDTH = 9;

    public static final DeferredRegister<CreativeModeTab> TABS =
            DeferredRegister.create(
                    Registries.CREATIVE_MODE_TAB,
                    DroingosDecor.MOD_ID
            );

    public static final DeferredHolder<CreativeModeTab, CreativeModeTab> MAIN =
            TABS.register(
                    "main",
                    () -> CreativeModeTab.builder()
                            .title(Component.translatable(
                                    "itemGroup.droingos_decor.main"
                            ))
                            .icon(() -> DecorItems.BOBBLE_PARROT
                                    .get()
                                    .getDefaultInstance())
                            .displayItems((parameters, output) -> {
                                List<DecorDefinition> definitions =
                                        DecorDefinitionRegistry.creativeOrder();

                                DecorCategory activeCategory = null;
                                int occupiedSlots = 0;
                                int spacerIndex = 0;

                                for (DecorDefinition definition : definitions) {
                                    if (definition.category() != activeCategory) {
                                        int remainder =
                                                occupiedSlots
                                                        % CREATIVE_ROW_WIDTH;

                                        if (remainder != 0) {
                                            int padding =
                                                    CREATIVE_ROW_WIDTH
                                                            - remainder;

                                            for (
                                                    int index = 0;
                                                    index < padding;
                                                    index++
                                            ) {
                                                if (
                                                        spacerIndex
                                                                >= DecorItems
                                                                .CREATIVE_SPACERS
                                                                .size()
                                                ) {
                                                    throw new IllegalStateException(
                                                            "Not enough unique creative spacers"
                                                    );
                                                }

                                                output.accept(
                                                        DecorItems
                                                                .CREATIVE_SPACERS
                                                                .get(spacerIndex++)
                                                                .get()
                                                                .getDefaultInstance()
                                                );

                                                occupiedSlots++;
                                            }
                                        }

                                        occupiedSlots += addHeader(
                                                output,
                                                definition.category()
                                        );

                                        activeCategory = definition.category();
                                    }

                                    output.accept(definition.pickupStack());
                                    occupiedSlots++;
                                }
                            })
                            .build()
            );

    private DecorCreativeTabs() {
    }

    private static int addHeader(
            CreativeModeTab.Output output,
            DecorCategory category
    ) {
        for (
                DeferredItem<?> piece
                : DecorItems.creativeHeader(category)
        ) {
            output.accept(piece.get().getDefaultInstance());
        }

        return CREATIVE_ROW_WIDTH;
    }

    public static void register(IEventBus bus) {
        TABS.register(bus);
    }
}
'@

# ---------------------------------------------------------------------------
# 2) Add a tiny client-side pulse mailbox.
#
# Right-click already happens on the client, so no extra packet is required.
# The renderer consumes the pulse on the next rendered frame.
# ---------------------------------------------------------------------------

Write-Utf8NoBom `
    "src/main/java/net/droingo/decor/client/animation/BobbleheadInteractionPulses.java" `
@'
package net.droingo.decor.client.animation;

import net.droingo.decor.content.DecorContainerBlockEntity;

import java.util.Map;
import java.util.WeakHashMap;

/**
 * Client-side one-shot pulses generated by bobblehead interactions.
 *
 * Weak keys ensure unloaded block entities are not retained.
 */
public final class BobbleheadInteractionPulses {
    private static final Map<
            DecorContainerBlockEntity,
            boolean[]
            > PULSES = new WeakHashMap<>();

    private BobbleheadInteractionPulses() {
    }

    public static void trigger(
            DecorContainerBlockEntity container,
            int slot
    ) {
        if (container == null || slot < 0 || slot >= 4) {
            return;
        }

        boolean[] slots = PULSES.computeIfAbsent(
                container,
                ignored -> new boolean[4]
        );

        slots[slot] = true;
    }

    public static boolean consume(
            DecorContainerBlockEntity container,
            int slot
    ) {
        if (container == null || slot < 0 || slot >= 4) {
            return false;
        }

        boolean[] slots = PULSES.get(container);

        if (slots == null || !slots[slot]) {
            return false;
        }

        slots[slot] = false;
        return true;
    }
}
'@

# ---------------------------------------------------------------------------
# 3) Trigger the pulse from the existing parrot interaction.
# ---------------------------------------------------------------------------

Replace-Checked `
    "src/main/java/net/droingo/decor/registry/DecorDefinitionRegistry.java" `
@'
                        .interaction((level, pos, player, container, slot) -> {
                            if (!level.isClientSide) {
                                float pitch =
'@ `
@'
                        .interaction((level, pos, player, container, slot) -> {
                            if (level.isClientSide) {
                                net.droingo.decor.client.animation
                                        .BobbleheadInteractionPulses
                                        .trigger(container, slot);
                            } else {
                                float pitch =
'@ `
    "trigger a client-side bobble pulse on parrot right-click"

# ---------------------------------------------------------------------------
# 4) Let the renderer consume the pulse and kick the existing spring.
# ---------------------------------------------------------------------------

Replace-Checked `
    "src/main/java/net/droingo/decor/client/render/DecorContainerRenderer.java" `
@'
import net.droingo.decor.client.animation.BobbleheadMotionState;
'@ `
@'
import net.droingo.decor.client.animation.BobbleheadInteractionPulses;
import net.droingo.decor.client.animation.BobbleheadMotionState;
'@ `
    "import interaction pulse support"

Replace-Checked `
    "src/main/java/net/droingo/decor/client/render/DecorContainerRenderer.java" `
@'
        BobbleheadMotionState motion = getMotionState(blockEntity, slot);
        updateMotion(blockEntity, motion, centreX, centreZ, yawDegrees, render.pivot().y, partialTick);
'@ `
@'
        BobbleheadMotionState motion = getMotionState(blockEntity, slot);

        if (BobbleheadInteractionPulses.consume(blockEntity, slot)) {
            motion.addInteractionImpulse();
        }

        updateMotion(
                blockEntity,
                motion,
                centreX,
                centreZ,
                yawDegrees,
                render.pivot().y,
                partialTick
        );
'@ `
    "consume the parrot pulse in the renderer"

# ---------------------------------------------------------------------------
# 5) Add a brief natural kick to the existing spring.
# ---------------------------------------------------------------------------

Replace-Checked `
    "src/main/java/net/droingo/decor/client/animation/BobbleheadMotionState.java" `
@'
    private float pitchVelocity;
    private float rollVelocity;
'@ `
@'
    private float pitchVelocity;
    private float rollVelocity;

    private float interactionRollDirection = 1.0F;
'@ `
    "store alternating interaction roll direction"

Replace-Checked `
    "src/main/java/net/droingo/decor/client/animation/BobbleheadMotionState.java" `
@'
    public float getPitchDegrees() {
        return pitchDegrees;
    }
'@ `
@'
    /**
     * Gives the head a short nod and a small alternating sideways wobble.
     * This feeds the existing spring rather than running a separate animation.
     */
    public void addInteractionImpulse() {
        pitchVelocity += 6.5F;
        rollVelocity += 2.25F * interactionRollDirection;

        interactionRollDirection =
                -interactionRollDirection;
    }

    public float getPitchDegrees() {
        return pitchDegrees;
    }
'@ `
    "add the right-click bobble impulse"

Write-Host ""
Write-Host "Fixed creative category spacing and added parrot right-click bobble."
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
Write-Host "Check:"
Write-Host "  1. Overlays has its own header row below Wall Decor."
Write-Host "  2. Right-clicking the parrot plays the sound and briefly bobbles its head."
