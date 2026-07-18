package net.droingo.decor.content;

import net.droingo.decor.registry.DecorBlocks;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.util.Mth;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.context.UseOnContext;
import net.minecraft.world.level.Level;

public final class HalfDecorItem extends Item {
    public HalfDecorItem(Properties properties) {
        super(properties);
    }

    @Override
    public InteractionResult useOn(UseOnContext context) {
        if (context.getClickedFace() != Direction.UP) {
            return InteractionResult.PASS;
        }

        Level level = context.getLevel();
        BlockPos pos = context.getClickedPos().above();

        if (!level.getBlockState(pos).canBeReplaced()) {
            return InteractionResult.FAIL;
        }

        if (!level.isClientSide) {
            level.setBlock(
                    pos,
                    DecorBlocks.HALF_DECOR_CONTAINER
                            .get()
                            .defaultBlockState(),
                    3
            );

            if (
                    level.getBlockEntity(pos)
                            instanceof HalfDecorBlockEntity blockEntity
            ) {
                int desiredRotation =
                        Mth.floor(
                                (context.getRotation() + 11.25F)
                                        / 22.5F
                        ) & 15;

                while (
                        blockEntity.getRotation()
                                != desiredRotation
                ) {
                    blockEntity.rotate();
                }
            }

            if (
                    context.getPlayer() == null
                            || !context.getPlayer()
                            .getAbilities()
                            .instabuild
            ) {
                context.getItemInHand().shrink(1);
            }
        }

        return InteractionResult.sidedSuccess(level.isClientSide);
    }
}