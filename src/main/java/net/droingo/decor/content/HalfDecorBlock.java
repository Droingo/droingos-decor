package net.droingo.decor.content;

import com.mojang.serialization.MapCodec;
import net.droingo.decor.registry.DecorItems;
import net.minecraft.core.BlockPos;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.BaseEntityBlock;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.HitResult;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;
import org.jetbrains.annotations.Nullable;

public final class HalfDecorBlock extends BaseEntityBlock {
    public static final MapCodec<HalfDecorBlock> CODEC =
            simpleCodec(HalfDecorBlock::new);

    private static final VoxelShape SHAPE =
            Shapes.box(0.125D, 0.0D, 0.0625D, 0.875D, 0.4375D, 0.9375D);

    public HalfDecorBlock(Properties properties) {
        super(properties);
    }

    @Override
    protected MapCodec<? extends BaseEntityBlock> codec() {
        return CODEC;
    }

    @Override
    public RenderShape getRenderShape(BlockState state) {
        return RenderShape.INVISIBLE;
    }

    @Nullable
    @Override
    public BlockEntity newBlockEntity(BlockPos pos, BlockState state) {
        return new HalfDecorBlockEntity(pos, state);
    }

    @Override
    protected VoxelShape getShape(
            BlockState state,
            BlockGetter level,
            BlockPos pos,
            CollisionContext context
    ) {
        return SHAPE;
    }

    @Override
    protected VoxelShape getCollisionShape(
            BlockState state,
            BlockGetter level,
            BlockPos pos,
            CollisionContext context
    ) {
        return SHAPE;
    }

    @Override
    protected InteractionResult useWithoutItem(
            BlockState state,
            Level level,
            BlockPos pos,
            Player player,
            BlockHitResult hit
    ) {
        if (!(level.getBlockEntity(pos) instanceof HalfDecorBlockEntity blockEntity)) {
            return InteractionResult.PASS;
        }

        if (player.isShiftKeyDown()) {
            if (!level.isClientSide) {
                blockEntity.rotate();
            }
        } else if (!level.isClientSide) {
            blockEntity.startPlayAnimation();
        }

        return InteractionResult.sidedSuccess(level.isClientSide);
    }

    @Override
    public void attack(
            BlockState state,
            Level level,
            BlockPos pos,
            Player player
    ) {
        super.attack(state, level, pos, player);

        if (level.isClientSide) {
            return;
        }

        HitResult picked = player.pick(5.0D, 1.0F, false);

        if (
                !(picked instanceof BlockHitResult blockHit)
                        || !blockHit.getBlockPos().equals(pos)
        ) {
            return;
        }

        if (!player.getAbilities().instabuild) {
            ItemStack stack =
                    DecorItems.EARTH_ROAMER.get().getDefaultInstance();

            if (!player.getInventory().add(stack)) {
                popResource(level, pos, stack);
            }
        }

        level.removeBlock(pos, false);
    }
}