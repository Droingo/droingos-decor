package net.droingo.decor;

import com.mojang.logging.LogUtils;
import net.droingo.decor.compat.sable.SableCompat;
import net.droingo.decor.registry.DecorBlockEntities;
import net.droingo.decor.registry.DecorBlocks;
import net.droingo.decor.registry.DecorCreativeTabs;
import net.droingo.decor.registry.DecorDefinitionRegistry;
import net.droingo.decor.registry.DecorItems;
import net.droingo.decor.registry.DecorSounds;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.ModList;
import net.neoforged.fml.common.Mod;
import org.slf4j.Logger;

@Mod(DroingosDecor.MOD_ID)
public final class DroingosDecor {
    public static final String MOD_ID = "droingos_decor";
    public static final Logger LOGGER = LogUtils.getLogger();

    public DroingosDecor(IEventBus modBus) {
        DecorBlocks.register(modBus);
        DecorItems.register(modBus);
        DecorSounds.register(modBus);
        DecorBlockEntities.register(modBus);
        DecorDefinitionRegistry.bootstrap();
        DecorCreativeTabs.register(modBus);

        if (ModList.get().isLoaded("sable")) {
            SableCompat.init();
        }

        LOGGER.info("Droingo's Decor loaded.");
    }
}