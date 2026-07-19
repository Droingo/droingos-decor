package net.droingo.decor.registry;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.entity.BeastSkullSeatEntity;
import net.minecraft.core.registries.Registries;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.MobCategory;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforge.registries.DeferredHolder;
import net.neoforged.neoforge.registries.DeferredRegister;

public final class DecorEntities {
    public static final DeferredRegister<EntityType<?>> ENTITY_TYPES =
            DeferredRegister.create(Registries.ENTITY_TYPE, DroingosDecor.MOD_ID);

    public static final DeferredHolder<EntityType<?>, EntityType<BeastSkullSeatEntity>> BEAST_SKULL_SEAT =
            ENTITY_TYPES.register(
                    "beast_skull_seat",
                    () -> EntityType.Builder
                            .<BeastSkullSeatEntity>of(
                                    BeastSkullSeatEntity::new,
                                    MobCategory.MISC
                            )
                            .sized(0.1F, 0.1F)
                            .clientTrackingRange(8)
                            .updateInterval(1)
                            .build("beast_skull_seat")
            );

    private DecorEntities() {
    }

    public static void register(IEventBus bus) {
        ENTITY_TYPES.register(bus);
    }
}