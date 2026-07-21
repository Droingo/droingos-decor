package net.droingo.decor.registry;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.content.CeilingPlantBlock;
import net.droingo.decor.content.BeastSkullBlock;
import net.droingo.decor.content.DecorContainerBlock;
import net.droingo.decor.content.HalfDecorBlock;
import net.droingo.decor.content.WallDecorBlock;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.material.MapColor;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforge.registries.DeferredBlock;
import net.neoforged.neoforge.registries.DeferredRegister;

public final class DecorBlocks {
    public static final DeferredRegister.Blocks BLOCKS =
            DeferredRegister.createBlocks(DroingosDecor.MOD_ID);

    public static final DeferredBlock<BeastSkullBlock> THE_BEAST_SKULL =
            BLOCKS.registerBlock(
                    "the_beast_skull",
                    BeastSkullBlock::new,
                    BlockBehaviour.Properties.of()
                            .mapColor(MapColor.COLOR_BROWN)
                            .strength(1.2F)
                            .sound(SoundType.BONE_BLOCK)
                            .noOcclusion()
                            .noCollission()
            );
    public static final DeferredBlock<CeilingPlantBlock> CEILING_PLANT =
            BLOCKS.registerBlock(
                    "ceiling_plant",
                    CeilingPlantBlock::new,
                    BlockBehaviour.Properties.of()
                            .mapColor(MapColor.PLANT)
                            .strength(0.2F)
                            .sound(SoundType.WOOD)
                            .noOcclusion()
                            .noCollission()
            );
    public static final DeferredBlock<DecorContainerBlock> DECOR_CONTAINER =
            BLOCKS.registerBlock(
                    "decor_container",
                    DecorContainerBlock::new,
                    BlockBehaviour.Properties.of()
                            .mapColor(MapColor.NONE)
                            .strength(0.2F)
                            .sound(SoundType.WOOD)
                            .noOcclusion()
                            .noCollission()
            );

    public static final DeferredBlock<HalfDecorBlock> HALF_DECOR_CONTAINER =
            BLOCKS.registerBlock(
                    "half_decor_container",
                    HalfDecorBlock::new,
                    BlockBehaviour.Properties.of()
                            .mapColor(MapColor.NONE)
                            .strength(0.2F)
                            .sound(SoundType.WOOD)
                            .noOcclusion()
                            .noCollission()
            );

    public static final DeferredBlock<WallDecorBlock> WALL_DECOR_CONTAINER =
            BLOCKS.registerBlock(
                    "wall_decor_container",
                    WallDecorBlock::new,
                    BlockBehaviour.Properties.of()
                            .mapColor(MapColor.NONE)
                            .strength(0.2F)
                            .sound(SoundType.WOOL)
                            .noOcclusion()
                            .noCollission()
            );

    private DecorBlocks() {
    }

    public static void register(IEventBus bus) {
        BLOCKS.register(bus);
    }
}