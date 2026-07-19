package net.droingo.decor.content;

import net.droingo.decor.registry.DecorBlocks;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.util.Mth;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.context.UseOnContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.state.BlockState;

public final class CeilingPlantItem extends Item {
    public CeilingPlantItem(Properties properties) {
        super(properties);
    }

    @Override
    public InteractionResult useOn(UseOnContext context) {
        if (context.getClickedFace() != Direction.DOWN) {
            return InteractionResult.FAIL;
        }

        Level level = context.getLevel();
        BlockPos pos = context.getClickedPos().below();

        if (!level.getBlockState(pos).canBeReplaced()) {
            return InteractionResult.FAIL;
        }

        int rotation =
                Mth.floor(
                        (context.getRotation() + 11.25F)
                                / 22.5F
                ) & 15;

        BlockState state =
                DecorBlocks.CEILING_PLANT
                        .get()
                        .defaultBlockState()
                        .setValue(
                                CeilingPlantBlock.ROTATION,
                                rotation
                        );

        if (!state.canSurvive(level, pos)) {
            return InteractionResult.FAIL;
        }

        if (!level.isClientSide) {
            level.setBlock(pos, state, 3);

            if (
                    context.getPlayer() == null
                            || !context.getPlayer()
                            .getAbilities()
                            .instabuild
            ) {
                context.getItemInHand().shrink(1);
            }
        }

        return InteractionResult.sidedSuccess(
                level.isClientSide
        );
    }
}