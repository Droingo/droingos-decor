package net.droingo.decor.registry;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.api.DecorCategory;
import net.droingo.decor.content.HalfDecorItem;
import net.droingo.decor.content.TinyDecorItem;
import net.droingo.decor.content.WallDecorItem;
import net.droingo.decor.content.overlay.OverlayItem;
import net.minecraft.world.item.Item;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforge.registries.DeferredItem;
import net.neoforged.neoforge.registries.DeferredRegister;

import java.util.ArrayList;
import java.util.List;

public final class DecorItems {
    public static final DeferredRegister.Items ITEMS =
            DeferredRegister.createItems(DroingosDecor.MOD_ID);

    public static final DeferredItem<Item> EARTH_ROAMER = ITEMS.register(
            "earth_roamer",
            () -> new HalfDecorItem(new Item.Properties())
    );

    public static final DeferredItem<Item> BOBBLE_PARROT = ITEMS.register(
            "bobble_parrot",
            () -> new TinyDecorItem(
                    "bobble_parrot",
                    new Item.Properties()
            )
    );
    public static final DeferredItem<Item> PUMPKIN_BOBBLE = ITEMS.register(
            "pumpkin_bobble",
            () -> new TinyDecorItem(
                    "pumpkin_bobble",
                    new Item.Properties()
            )
    );

    public static final List<DeferredItem<Item>> CREATIVE_SPACERS =
            registerSpacers();

    public static final List<DeferredItem<Item>> BOBBLEHEAD_HEADER =
            registerHeader("bobbleheads");

    public static final List<DeferredItem<Item>> HALF_BLOCKS_HEADER =
            registerHeader("half_blocks");

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

    public static final DeferredItem<Item> HANGING_SWEATER = ITEMS.register(
            "hanging_sweater",
            () -> new WallDecorItem(
                    "hanging_sweater",
                    new Item.Properties()
            )
    );

    public static final DeferredItem<Item> MOSSY_BOTTOM = ITEMS.register(
            "mossy_bottom",
            () -> new OverlayItem(
                    "mossy_bottom",
                    new Item.Properties()
            )
    );

    public static final DeferredItem<Item> WET_BOTTOM = ITEMS.register(
            "wet_bottom",
            () -> new OverlayItem(
                    "wet_bottom",
                    new Item.Properties()
            )
    );

    public static final List<DeferredItem<Item>> OVERLAYS_HEADER =
            registerHeader("overlays");

    private DecorItems() {
    }

    private static DeferredItem<Item> registerInternalItem(String name) {
        return ITEMS.register(
                name,
                () -> new Item(
                        new Item.Properties().stacksTo(1)
                )
        );
    }

    private static List<DeferredItem<Item>> registerSpacers() {
        List<DeferredItem<Item>> spacers =
                new ArrayList<>(64);

        for (int index = 0; index < 64; index++) {
            spacers.add(
                    registerInternalItem(
                            "creative_spacer_" + index
                    )
            );
        }

        return List.copyOf(spacers);
    }

    private static List<DeferredItem<Item>> registerHeader(
            String categoryName
    ) {
        List<DeferredItem<Item>> pieces =
                new ArrayList<>(9);

        for (int index = 0; index < 9; index++) {
            pieces.add(
                    registerInternalItem(
                            "creative_header_"
                                    + categoryName
                                    + "_"
                                    + index
                    )
            );
        }

        return List.copyOf(pieces);
    }

    public static List<DeferredItem<Item>> creativeHeader(
            DecorCategory category
    ) {
        return switch (category) {
            case BOBBLEHEADS -> BOBBLEHEAD_HEADER;
            case HALF_BLOCKS -> HALF_BLOCKS_HEADER;
            case WALL_DECOR -> WALL_DECOR_HEADER;
            case HANGING_DECOR -> HANGING_DECOR_HEADER;
            case SMALL_DECOR -> SMALL_DECOR_HEADER;
            case FURNITURE -> FURNITURE_HEADER;
            case LIGHTING -> LIGHTING_HEADER;
            case OUTDOOR_DECOR -> OUTDOOR_DECOR_HEADER;
            case OVERLAYS -> OVERLAYS_HEADER;
        };
    }

    public static void register(IEventBus bus) {
        ITEMS.register(bus);
    }
}
