package net.droingo.decor.registry;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.content.CeilingPlantBlockEntity;
import net.droingo.decor.content.BeastSkullBlockEntity;
import net.droingo.decor.content.DecorContainerBlockEntity;
import net.droingo.decor.content.HalfDecorBlockEntity;
import net.droingo.decor.content.WallDecorBlockEntity;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforge.registries.DeferredHolder;
import net.neoforged.neoforge.registries.DeferredRegister;

public final class DecorBlockEntities {
    public static final DeferredRegister<BlockEntityType<?>> TYPES =
            DeferredRegister.create(
                    BuiltInRegistries.BLOCK_ENTITY_TYPE,
                    DroingosDecor.MOD_ID
            );

    public static final DeferredHolder<
            BlockEntityType<?>,
            BlockEntityType<BeastSkullBlockEntity>
            > BEAST_SKULL = TYPES.register(
            "the_beast_skull",
            () -> BlockEntityType.Builder.of(
                    BeastSkullBlockEntity::new,
                    DecorBlocks.THE_BEAST_SKULL.get()
            ).build(null)
    );
    public static final DeferredHolder<
            BlockEntityType<?>,
            BlockEntityType<CeilingPlantBlockEntity>
            > CEILING_PLANT = TYPES.register(
            "ceiling_plant",
            () -> BlockEntityType.Builder.of(
                    CeilingPlantBlockEntity::new,
                    DecorBlocks.CEILING_PLANT.get()
            ).build(null)
    );
    public static final DeferredHolder<
            BlockEntityType<?>,
            BlockEntityType<DecorContainerBlockEntity>
            > DECOR_CONTAINER = TYPES.register(
            "decor_container",
            () -> BlockEntityType.Builder.of(
                    DecorContainerBlockEntity::new,
                    DecorBlocks.DECOR_CONTAINER.get()
            ).build(null)
    );

    public static final DeferredHolder<
            BlockEntityType<?>,
            BlockEntityType<HalfDecorBlockEntity>
            > HALF_DECOR_CONTAINER = TYPES.register(
            "half_decor_container",
            () -> BlockEntityType.Builder.of(
                    HalfDecorBlockEntity::new,
                    DecorBlocks.HALF_DECOR_CONTAINER.get()
            ).build(null)
    );

    public static final DeferredHolder<
            BlockEntityType<?>,
            BlockEntityType<WallDecorBlockEntity>
            > WALL_DECOR_CONTAINER = TYPES.register(
            "wall_decor_container",
            () -> BlockEntityType.Builder.of(
                    WallDecorBlockEntity::new,
                    DecorBlocks.WALL_DECOR_CONTAINER.get()
            ).build(null)
    );

    private DecorBlockEntities() {
    }

    public static void register(IEventBus bus) {
        TYPES.register(bus);
    }
}