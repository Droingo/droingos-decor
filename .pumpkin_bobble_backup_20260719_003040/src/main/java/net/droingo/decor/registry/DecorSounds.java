package net.droingo.decor.registry;

import net.droingo.decor.DroingosDecor;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.sounds.SoundEvent;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforge.registries.DeferredHolder;
import net.neoforged.neoforge.registries.DeferredRegister;

public final class DecorSounds {
    public static final DeferredRegister<SoundEvent> SOUNDS =
            DeferredRegister.create(
                    Registries.SOUND_EVENT,
                    DroingosDecor.MOD_ID
            );

    public static final DeferredHolder<SoundEvent, SoundEvent> PUMPKIN_CAW =
            SOUNDS.register(
                    "pumpkin_caw",
                    () -> SoundEvent.createVariableRangeEvent(
                            ResourceLocation.fromNamespaceAndPath(
                                    DroingosDecor.MOD_ID,
                                    "pumpkin_caw"
                            )
                    )
            );

    private DecorSounds() {
    }

    public static void register(IEventBus bus) {
        SOUNDS.register(bus);
    }
}