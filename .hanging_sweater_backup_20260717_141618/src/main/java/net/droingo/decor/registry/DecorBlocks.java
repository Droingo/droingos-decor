package net.droingo.decor.registry;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.content.DecorContainerBlock;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.material.MapColor;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforge.registries.DeferredBlock;
import net.neoforged.neoforge.registries.DeferredRegister;

public final class DecorBlocks {
    public static final DeferredRegister.Blocks BLOCKS = DeferredRegister.createBlocks(DroingosDecor.MOD_ID);
    public static final DeferredBlock<DecorContainerBlock> DECOR_CONTAINER = BLOCKS.registerBlock(
            "decor_container",
            DecorContainerBlock::new,
            BlockBehaviour.Properties.of().mapColor(MapColor.NONE).strength(0.2F).sound(SoundType.WOOD)
                    .noOcclusion().noCollission()
    );
    private DecorBlocks() {}
    public static void register(IEventBus bus) { BLOCKS.register(bus); }
}
