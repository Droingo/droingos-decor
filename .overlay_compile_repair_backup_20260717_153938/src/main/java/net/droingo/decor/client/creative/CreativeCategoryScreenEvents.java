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
import net.neoforged.neoforge.client.event.ContainerScreenEvent;
import net.neoforged.neoforge.client.event.RenderTooltipEvent;
import net.neoforged.neoforge.client.event.ScreenEvent;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Draws non-interactive category banners over transparent layout-marker rows
 * inside Droingo's Decor's creative tab.
 */
@EventBusSubscriber(
        modid = DroingosDecor.MOD_ID,
        value = Dist.CLIENT
)
public final class CreativeCategoryScreenEvents {
    private static final String HEADER_PREFIX = "creative_header_";

    /*
     * Creative slots are positioned 18 pixels apart, but the visible grid
     * from the first slot edge to the final slot edge is:
     *
     * 8 gaps × 18 pixels + final slot width of 16 pixels = 160 pixels.
     */
    private static final int HEADER_WIDTH = 160;
    private static final int HEADER_HEIGHT = 18;

    private static final int BACKGROUND = 0xFF353535;
    private static final int TOP_BORDER = 0xFF686868;
    private static final int BOTTOM_BORDER = 0xFF171717;
    private static final int TEXT = 0xFFF2F2F2;
    private static final int TEXT_SHADOW = 0xFF111111;

    private static final Map<String, Component> LABELS = createLabels();

    private CreativeCategoryScreenEvents() {
    }

    /*
     * This event occurs after the slots and foreground have rendered, but
     * before Minecraft renders tooltips and dragged item stacks.
     *
     * That lets the banner cover the reserved slot row without covering the
     * tooltip of a genuine decor item.
     */
    @SubscribeEvent
    public static void renderForeground(
            ContainerScreenEvent.Render.Foreground event
    ) {
        if (!(event.getContainerScreen()
                instanceof CreativeModeInventoryScreen screen)) {
            return;
        }

        GuiGraphics graphics = event.getGuiGraphics();

        for (Slot slot : screen.getMenu().slots) {
            String category = categoryFromFirstPiece(slot.getItem());

            if (category == null) {
                continue;
            }

            Component label = LABELS.get(category);

            if (label == null) {
                continue;
            }

            /*
             * ContainerScreenEvent coordinates are already based on the
             * screen, while slot.x and slot.y are relative to the GUI.
             */
            int x = slot.x;
            int y = slot.y - 1;

            drawHeader(
                    graphics,
                    x,
                    y,
                    label
            );
        }
    }

    private static void drawHeader(
            GuiGraphics graphics,
            int x,
            int y,
            Component label
    ) {
        graphics.pose().pushPose();

        /*
         * Draw above slot items, but remain below the tooltip stage that runs
         * after this event.
         */
        graphics.pose().translate(0.0F, 0.0F, 250.0F);

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

        int textY =
                y + (HEADER_HEIGHT - minecraft.font.lineHeight) / 2;

        graphics.drawString(
                minecraft.font,
                label,
                x + 7,
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

    @SubscribeEvent
    public static void beforeMousePressed(
            ScreenEvent.MouseButtonPressed.Pre event
    ) {
        if (!(event.getScreen()
                instanceof CreativeModeInventoryScreen screen)) {
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
        if (!(event.getScreen()
                instanceof CreativeModeInventoryScreen screen)) {
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
    public static void beforeTooltip(
            RenderTooltipEvent.Pre event
    ) {
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

    private static String categoryFromFirstPiece(
            ItemStack stack
    ) {
        if (stack.isEmpty()) {
            return null;
        }

        ResourceLocation id =
                BuiltInRegistries.ITEM.getKey(stack.getItem());

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

    private static boolean isLayoutMarker(
            ItemStack stack
    ) {
        if (stack.isEmpty()) {
            return false;
        }

        ResourceLocation id =
                BuiltInRegistries.ITEM.getKey(stack.getItem());

        if (!DroingosDecor.MOD_ID.equals(id.getNamespace())) {
            return false;
        }

        String path = id.getPath();

        return path.startsWith("creative_spacer_")
                || path.startsWith(HEADER_PREFIX);
    }

    private static Map<String, Component> createLabels() {
        Map<String, Component> labels = new LinkedHashMap<>();

        labels.put(
                "bobbleheads",
                Component.literal("Bobbleheads")
        );

        labels.put(
                "wall_decor",
                Component.literal("Wall Decor")
        );

        labels.put(
                "hanging_decor",
                Component.literal("Hanging Decor")
        );

        labels.put(
                "small_decor",
                Component.literal("Small Decor")
        );

        labels.put(
                "furniture",
                Component.literal("Furniture")
        );

        labels.put(
                "lighting",
                Component.literal("Lighting")
        );

        labels.put(
                "outdoor_decor",
                Component.literal("Outdoor Decor")
        );

        labels.put("overlays", Component.literal("Overlays"));`r`n`r`n        return Map.copyOf(labels);
    }
}