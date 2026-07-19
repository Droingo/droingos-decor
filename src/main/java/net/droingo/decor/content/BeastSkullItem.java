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

public final class BeastSkullItem extends Item {
    public BeastSkullItem(Properties properties) {
        super(properties);
    }

    @Override
    public InteractionResult useOn(UseOnContext context) {
        Level level = context.getLevel();
        Direction clickedFace = context.getClickedFace();
        BlockPos pos = context.getClickedPos().relative(clickedFace);

        if (!level.getBlockState(pos).canBeReplaced()) {
            return InteractionResult.FAIL;
        }

        BeastSkullPlacement placement =
                clickedFace == Direction.UP
                        ? BeastSkullPlacement.FLOOR
                        : clickedFace == Direction.DOWN
                        ? BeastSkullPlacement.CEILING
                        : BeastSkullPlacement.WALL;

        Direction facing =
                placement == BeastSkullPlacement.WALL
                        ? clickedFace
                        : context.getHorizontalDirection().getOpposite();

        int rotation =
                Mth.floor(
                        (
                                context.getRotation()
                                        + 11.25F
                        ) / 22.5F
                ) & 15;

        BlockState state =
                DecorBlocks.THE_BEAST_SKULL
                        .get()
                        .defaultBlockState()
                        .setValue(
                                BeastSkullBlock.PLACEMENT,
                                placement
                        )
                        .setValue(
                                BeastSkullBlock.FACING,
                                facing
                        )
                        .setValue(
                                BeastSkullBlock.ROTATION,
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