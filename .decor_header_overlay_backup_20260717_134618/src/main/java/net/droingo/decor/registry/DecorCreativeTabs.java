
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
