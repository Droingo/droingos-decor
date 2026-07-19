package net.droingo.decor.content;

import net.droingo.decor.registry.DecorBlockEntities;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;

public final class CeilingPlantBlockEntity extends BlockEntity {
    public CeilingPlantBlockEntity(
            BlockPos pos,
            BlockState state
    ) {
        super(
                DecorBlockEntities.CEILING_PLANT.get(),
                pos,
                state
        );
    }
}