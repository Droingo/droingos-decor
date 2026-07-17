$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$ProjectRoot = (Get-Location).Path
$BackupRoot = Join-Path $ProjectRoot (".decor_header_overlay_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $Target = Join-Path $ProjectRoot $RelativePath

    if (Test-Path -LiteralPath $Target) {
        $Backup = Join-Path $BackupRoot $RelativePath
        $BackupDirectory = Split-Path -Parent $Backup
        New-Item -ItemType Directory -Force -Path $BackupDirectory | Out-Null
        Copy-Item -LiteralPath $Target -Destination $Backup -Force
    }

    $Directory = Split-Path -Parent $Target
    New-Item -ItemType Directory -Force -Path $Directory | Out-Null
    [System.IO.File]::WriteAllText($Target, $Content, $Utf8NoBom)
}

function Write-Base64File {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Base64
    )

    $Target = Join-Path $ProjectRoot $RelativePath

    if (Test-Path -LiteralPath $Target) {
        $Backup = Join-Path $BackupRoot $RelativePath
        $BackupDirectory = Split-Path -Parent $Backup
        New-Item -ItemType Directory -Force -Path $BackupDirectory | Out-Null
        Copy-Item -LiteralPath $Target -Destination $Backup -Force
    }

    $Directory = Split-Path -Parent $Target
    New-Item -ItemType Directory -Force -Path $Directory | Out-Null
    [System.IO.File]::WriteAllBytes(
        $Target,
        [Convert]::FromBase64String($Base64)
    )
}

if (!(Test-Path -LiteralPath (Join-Path $ProjectRoot "build.gradle"))) {
    throw "Run this script from the Droingo's Decor project root."
}

Write-Utf8NoBom "src/main/java/net/droingo/decor/registry/DecorItems.java" @'
package net.droingo.decor.registry;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.api.DecorCategory;
import net.droingo.decor.content.TinyDecorItem;
import net.minecraft.world.item.Item;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforge.registries.DeferredItem;
import net.neoforged.neoforge.registries.DeferredRegister;

import java.util.ArrayList;
import java.util.List;

public final class DecorItems {
    public static final DeferredRegister.Items ITEMS =
            DeferredRegister.createItems(DroingosDecor.MOD_ID);

    public static final DeferredItem<Item> BOBBLE_PARROT = ITEMS.register(
            "bobble_parrot",
            () -> new TinyDecorItem("bobble_parrot", new Item.Properties())
    );

    /*
     * Internal layout markers used only to reserve category rows.
     *
     * They render transparently and are covered by the client-side category
     * banner. Mouse input and tooltips are suppressed by
     * CreativeCategoryScreenEvents.
     */
    public static final DeferredItem<Item> CREATIVE_SPACER =
            registerInternalItem("creative_spacer");

    public static final List<DeferredItem<Item>> BOBBLEHEAD_HEADER =
            registerHeader("bobbleheads");

    public static final List<DeferredItem<Item>> WALL_DECOR_HEADER =
            registerHeader("wall_decor");

    public static final List<DeferredItem<Item>> HANGING_DECOR_HEADER =
            registerHeader("hanging_decor");

    public static final List<DeferredItem<Item>> SMALL_DECOR_HEADER =
            registerHeader("small_decor");

    public static final List<DeferredItem<Item>> FURNITURE_HEADER =
            registerHeader("furniture");

    public static final List<DeferredItem<Item>> LIGHTING_HEADER =
            registerHeader("lighting");

    public static final List<DeferredItem<Item>> OUTDOOR_DECOR_HEADER =
            registerHeader("outdoor_decor");

    private DecorItems() {
    }

    private static DeferredItem<Item> registerInternalItem(String name) {
        return ITEMS.register(
                name,
                () -> new Item(new Item.Properties().stacksTo(1))
        );
    }

    private static List<DeferredItem<Item>> registerHeader(String categoryName) {
        List<DeferredItem<Item>> pieces = new ArrayList<>(9);

        for (int index = 0; index < 9; index++) {
            pieces.add(registerInternalItem(
                    "creative_header_" + categoryName + "_" + index
            ));
        }

        return List.copyOf(pieces);
    }

    public static List<DeferredItem<Item>> creativeHeader(
            DecorCategory category
    ) {
        return switch (category) {
            case BOBBLEHEADS -> BOBBLEHEAD_HEADER;
            case WALL_DECOR -> WALL_DECOR_HEADER;
            case HANGING_DECOR -> HANGING_DECOR_HEADER;
            case SMALL_DECOR -> SMALL_DECOR_HEADER;
            case FURNITURE -> FURNITURE_HEADER;
            case LIGHTING -> LIGHTING_HEADER;
            case OUTDOOR_DECOR -> OUTDOOR_DECOR_HEADER;
        };
    }

    public static void register(IEventBus bus) {
        ITEMS.register(bus);
    }
}
'@
Write-Utf8NoBom "src/main/java/net/droingo/decor/registry/DecorCreativeTabs.java" @'
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

                                for (DecorDefinition definition : definitions) {
                                    if (definition.category() != activeCategory) {
                                        occupiedSlots = padToNextRow(
                                                output,
                                                occupiedSlots
                                        );

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

    private static int padToNextRow(
            CreativeModeTab.Output output,
            int occupiedSlots
    ) {
        int remainder = occupiedSlots % CREATIVE_ROW_WIDTH;

        if (remainder == 0) {
            return occupiedSlots;
        }

        int padding = CREATIVE_ROW_WIDTH - remainder;

        for (int index = 0; index < padding; index++) {
            output.accept(
                    DecorItems.CREATIVE_SPACER.get().getDefaultInstance()
            );
        }

        return occupiedSlots + padding;
    }

    private static int addHeader(
            CreativeModeTab.Output output,
            DecorCategory category
    ) {
        for (DeferredItem<?> piece : DecorItems.creativeHeader(category)) {
            output.accept(piece.get().getDefaultInstance());
        }

        return CREATIVE_ROW_WIDTH;
    }

    public static void register(IEventBus bus) {
        TABS.register(bus);
    }
}
'@
Write-Utf8NoBom "src/main/java/net/droingo/decor/client/creative/CreativeCategoryScreenEvents.java" @'
package net.droingo.decor.client.creative;

import net.droingo.decor.DroingosDecor;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.screens.inventory.CreativeModeInventoryScreen;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.inventory.Slot;
import net.minecraft.world.item.ItemStack;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.client.event.RenderTooltipEvent;
import net.neoforged.neoforge.client.event.ScreenEvent;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Draws non-interactive full-width category banners over the transparent
 * layout-marker row in Droingo's Decor's creative tab.
 */
@EventBusSubscriber(
        modid = DroingosDecor.MOD_ID,
        value = Dist.CLIENT
)
public final class CreativeCategoryScreenEvents {
    private static final String HEADER_PREFIX = "creative_header_";

    private static final int SLOT_SIZE = 18;
    private static final int HEADER_WIDTH = SLOT_SIZE * 9;
    private static final int HEADER_HEIGHT = SLOT_SIZE;

    private static final int BACKGROUND = 0xFF353535;
    private static final int TOP_BORDER = 0xFF686868;
    private static final int BOTTOM_BORDER = 0xFF171717;
    private static final int TEXT = 0xFFF2F2F2;
    private static final int TEXT_SHADOW = 0xFF111111;

    private static final Map<String, Component> LABELS = createLabels();

    private CreativeCategoryScreenEvents() {
    }

    @SubscribeEvent
    public static void afterScreenRender(ScreenEvent.Render.Post event) {
        if (!(event.getScreen() instanceof CreativeModeInventoryScreen screen)) {
            return;
        }

        GuiGraphics graphics = event.getGuiGraphics();
        int left = screen.getGuiLeft();
        int top = screen.getGuiTop();

        /*
         * Only the first marker piece in each row draws the complete banner.
         * The remaining eight pieces merely reserve the row.
         */
        for (Slot slot : screen.getMenu().slots) {
            String category = categoryFromFirstPiece(slot.getItem());

            if (category == null) {
                continue;
            }

            Component label = LABELS.get(category);

            if (label == null) {
                continue;
            }

            int x = left + slot.x;
            int y = top + slot.y;

            graphics.pose().pushPose();
            graphics.pose().translate(0.0F, 0.0F, 500.0F);

            graphics.fill(
                    x,
                    y,
                    x + HEADER_WIDTH,
                    y + HEADER_HEIGHT,
                    BACKGROUND
            );

            graphics.fill(
                    x,
                    y,
                    x + HEADER_WIDTH,
                    y + 1,
                    TOP_BORDER
            );

            graphics.fill(
                    x,
                    y + HEADER_HEIGHT - 1,
                    x + HEADER_WIDTH,
                    y + HEADER_HEIGHT,
                    BOTTOM_BORDER
            );

            Minecraft minecraft = Minecraft.getInstance();
            int textY = y + (HEADER_HEIGHT - minecraft.font.lineHeight) / 2;

            graphics.drawString(
                    minecraft.font,
                    label,
                    x + 6 + 1,
                    textY + 1,
                    TEXT_SHADOW,
                    false
            );

            graphics.drawString(
                    minecraft.font,
                    label,
                    x + 6,
                    textY,
                    TEXT,
                    false
            );

            graphics.pose().popPose();
        }
    }

    @SubscribeEvent
    public static void beforeMousePressed(
            ScreenEvent.MouseButtonPressed.Pre event
    ) {
        if (!(event.getScreen() instanceof CreativeModeInventoryScreen screen)) {
            return;
        }

        if (isOverHeaderRow(
                screen,
                event.getMouseX(),
                event.getMouseY()
        )) {
            event.setCanceled(true);
        }
    }

    @SubscribeEvent
    public static void beforeMouseDragged(
            ScreenEvent.MouseDragged.Pre event
    ) {
        if (!(event.getScreen() instanceof CreativeModeInventoryScreen screen)) {
            return;
        }

        if (isOverHeaderRow(
                screen,
                event.getMouseX(),
                event.getMouseY()
        )) {
            event.setCanceled(true);
        }
    }

    @SubscribeEvent
    public static void beforeTooltip(RenderTooltipEvent.Pre event) {
        if (isLayoutMarker(event.getItemStack())) {
            event.setCanceled(true);
        }
    }

    private static boolean isOverHeaderRow(
            CreativeModeInventoryScreen screen,
            double mouseX,
            double mouseY
    ) {
        int left = screen.getGuiLeft();
        int top = screen.getGuiTop();

        for (Slot slot : screen.getMenu().slots) {
            if (categoryFromFirstPiece(slot.getItem()) == null) {
                continue;
            }

            int x = left + slot.x;
            int y = top + slot.y;

            if (
                    mouseX >= x
                            && mouseX < x + HEADER_WIDTH
                            && mouseY >= y
                            && mouseY < y + HEADER_HEIGHT
            ) {
                return true;
            }
        }

        return false;
    }

    private static String categoryFromFirstPiece(ItemStack stack) {
        ResourceLocation id = BuiltInRegistries.ITEM.getKey(stack.getItem());

        if (!DroingosDecor.MOD_ID.equals(id.getNamespace())) {
            return null;
        }

        String path = id.getPath();

        if (
                !path.startsWith(HEADER_PREFIX)
                        || !path.endsWith("_0")
        ) {
            return null;
        }

        return path.substring(
                HEADER_PREFIX.length(),
                path.length() - 2
        );
    }

    private static boolean isLayoutMarker(ItemStack stack) {
        if (stack.isEmpty()) {
            return false;
        }

        ResourceLocation id = BuiltInRegistries.ITEM.getKey(stack.getItem());

        if (!DroingosDecor.MOD_ID.equals(id.getNamespace())) {
            return false;
        }

        String path = id.getPath();

        return path.equals("creative_spacer")
                || path.startsWith(HEADER_PREFIX);
    }

    private static Map<String, Component> createLabels() {
        Map<String, Component> labels = new LinkedHashMap<>();

        labels.put("bobbleheads", Component.literal("Bobbleheads"));
        labels.put("wall_decor", Component.literal("Wall Decor"));
        labels.put("hanging_decor", Component.literal("Hanging Decor"));
        labels.put("small_decor", Component.literal("Small Decor"));
        labels.put("furniture", Component.literal("Furniture"));
        labels.put("lighting", Component.literal("Lighting"));
        labels.put("outdoor_decor", Component.literal("Outdoor Decor"));

        return Map.copyOf(labels);
    }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_spacer.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_bobbleheads_0.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_bobbleheads_1.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_bobbleheads_2.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_bobbleheads_3.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_bobbleheads_4.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_bobbleheads_5.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_bobbleheads_6.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_bobbleheads_7.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_bobbleheads_8.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_wall_decor_0.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_wall_decor_1.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_wall_decor_2.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_wall_decor_3.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_wall_decor_4.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_wall_decor_5.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_wall_decor_6.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_wall_decor_7.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_wall_decor_8.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_hanging_decor_0.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_hanging_decor_1.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_hanging_decor_2.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_hanging_decor_3.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_hanging_decor_4.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_hanging_decor_5.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_hanging_decor_6.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_hanging_decor_7.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_hanging_decor_8.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_small_decor_0.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_small_decor_1.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_small_decor_2.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_small_decor_3.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_small_decor_4.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_small_decor_5.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_small_decor_6.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_small_decor_7.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_small_decor_8.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_furniture_0.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_furniture_1.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_furniture_2.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_furniture_3.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_furniture_4.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_furniture_5.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_furniture_6.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_furniture_7.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_furniture_8.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_lighting_0.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_lighting_1.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_lighting_2.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_lighting_3.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_lighting_4.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_lighting_5.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_lighting_6.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_lighting_7.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_lighting_8.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_outdoor_decor_0.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_outdoor_decor_1.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_outdoor_decor_2.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_outdoor_decor_3.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_outdoor_decor_4.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_outdoor_decor_5.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_outdoor_decor_6.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_outdoor_decor_7.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/creative_header_outdoor_decor_8.json" @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@
Write-Base64File "src/main/resources/assets/droingos_decor/textures/item/creative_layout_marker.png" "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAEklEQVR4nGNgGAWjYBSMAggAAAQQAAFVN1rQAAAAAElFTkSuQmCC"

Write-Host ""
Write-Host "Installed non-interactive creative category banners."
Write-Host "Backup directory: $BackupRoot"
Write-Host ""
Write-Host "Building..."
Write-Host ""

& .\gradlew.bat build

if ($LASTEXITCODE -ne 0) {
    throw "Build failed. Original files are available in: $BackupRoot"
}

Write-Host ""
Write-Host "Build successful."
