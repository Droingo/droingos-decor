package net.droingo.decor.registry;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.api.DecorDefinition;
import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.CreativeModeTab;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforge.registries.DeferredHolder;
import net.neoforged.neoforge.registries.DeferredRegister;

public final class DecorCreativeTabs {
    public static final DeferredRegister<CreativeModeTab> TABS =
            DeferredRegister.create(Registries.CREATIVE_MODE_TAB, DroingosDecor.MOD_ID);

    public static final DeferredHolder<CreativeModeTab, CreativeModeTab> MAIN = TABS.register(
            "main",
            () -> CreativeModeTab.builder()
                    .title(Component.translatable("itemGroup.droingos_decor.main"))
                    .icon(() -> DecorItems.BOBBLE_PARROT.get().getDefaultInstance())
                    .displayItems((parameters, output) -> {
                        for (DecorDefinition definition : DecorDefinitionRegistry.creativeOrder()) {
                            output.accept(definition.pickupStack());
                        }
                    })
                    .build()
    );

    private DecorCreativeTabs() {
    }

    public static void register(IEventBus bus) {
        TABS.register(bus);
    }
}