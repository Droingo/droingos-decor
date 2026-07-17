package net.droingo.decor.content;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.registry.DecorBlocks;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.context.UseOnContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.state.BlockState;

public final class WallDecorItem extends Item {
    private final ResourceLocation decorId;

    public WallDecorItem(String id, Properties properties) {
        super(properties);
        this.decorId = ResourceLocation.fromNamespaceAndPath(
                DroingosDecor.MOD_ID,
                id
        );
    }

    @Override
    public InteractionResult useOn(UseOnContext context) {
        Direction clickedFace = context.getClickedFace();

        if (!clickedFace.getAxis().isHorizontal()) {
            return InteractionResult.PASS;
        }

        Level level = context.getLevel();
        BlockPos placementPos = context.getClickedPos().relative(clickedFace);

        if (!level.getBlockState(placementPos).canBeReplaced()) {
            return InteractionResult.FAIL;
        }

        Direction supportDirection = clickedFace.getOpposite();

        BlockState placementState = DecorBlocks.WALL_DECOR_CONTAINER
                .get()
                .defaultBlockState()
                .setValue(WallDecorBlock.FACING, supportDirection);

        if (!level.isClientSide) {
            level.setBlock(placementPos, placementState, 3);

            if (
                    !(level.getBlockEntity(placementPos)
                    instanceof WallDecorBlockEntity blockEntity)
            ) {
                level.removeBlock(placementPos, false);
                return InteractionResult.FAIL;
            }

            blockEntity.setDecorId(decorId);

            if (
                    context.getPlayer() == null
                            || !context.getPlayer().getAbilities().instabuild
            ) {
                context.getItemInHand().shrink(1);
            }
        }

        return InteractionResult.sidedSuccess(level.isClientSide);
    }
}