package net.droingo.decor.registry;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.content.TinyDecorItem;
import net.minecraft.world.item.Item;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforge.registries.DeferredItem;
import net.neoforged.neoforge.registries.DeferredRegister;

public final class DecorItems {
    public static final DeferredRegister.Items ITEMS = DeferredRegister.createItems(DroingosDecor.MOD_ID);
    public static final DeferredItem<Item> BOBBLE_PARROT = ITEMS.register("bobble_parrot",
            () -> new TinyDecorItem("bobble_parrot", new Item.Properties()));
    private DecorItems() {}
    public static void register(IEventBus bus) { ITEMS.register(bus); }
}
