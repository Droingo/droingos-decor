package net.droingo.decor.content;

import com.mojang.serialization.MapCodec;
import net.droingo.decor.registry.DecorItems;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.BaseEntityBlock;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.SupportType;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.block.state.properties.IntegerProperty;
import net.minecraft.world.level.material.PushReaction;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;
import org.jetbrains.annotations.Nullable;

public final class CeilingPlantBlock extends BaseEntityBlock {
    public static final MapCodec<CeilingPlantBlock> CODEC =
            simpleCodec(CeilingPlantBlock::new);

    public static final IntegerProperty ROTATION =
            BlockStateProperties.ROTATION_16;

    private static final VoxelShape POT_SHAPE =
            Shapes.box(
                    5.5D / 16.0D,
                    7.0D / 16.0D,
                    5.5D / 16.0D,
                    10.5D / 16.0D,
                    1.0D,
                    10.5D / 16.0D
            );

    public CeilingPlantBlock(Properties properties) {
        super(properties);

        registerDefaultState(
                stateDefinition.any()
                        .setValue(ROTATION, 0)
        );
    }

    @Override
    protected MapCodec<? extends BaseEntityBlock> codec() {
        return CODEC;
    }

    @Override
    protected void createBlockStateDefinition(
            StateDefinition.Builder<
                    net.minecraft.world.level.block.Block,
                    BlockState
                    > builder
    ) {
        builder.add(ROTATION);
    }

    @Override
    public RenderShape getRenderShape(BlockState state) {
        return RenderShape.INVISIBLE;
    }

    @Nullable
    @Override
    public BlockEntity newBlockEntity(
            BlockPos pos,
            BlockState state
    ) {
        return new CeilingPlantBlockEntity(pos, state);
    }

    @Override
    protected VoxelShape getShape(
            BlockState state,
            BlockGetter level,
            BlockPos pos,
            CollisionContext context
    ) {
        return POT_SHAPE;
    }

    @Override
    protected VoxelShape getCollisionShape(
            BlockState state,
            BlockGetter level,
            BlockPos pos,
            CollisionContext context
    ) {
        return Shapes.empty();
    }

    @Override
    protected boolean canSurvive(
            BlockState state,
            net.minecraft.world.level.LevelReader level,
            BlockPos pos
    ) {
        BlockPos supportPos = pos.above();

        return level.getBlockState(supportPos)
                .isFaceSturdy(
                        level,
                        supportPos,
                        Direction.DOWN,
                        SupportType.CENTER
                );
    }

    @Override
    protected BlockState updateShape(
            BlockState state,
            Direction direction,
            BlockState neighbourState,
            net.minecraft.world.level.LevelAccessor level,
            BlockPos pos,
            BlockPos neighbourPos
    ) {
        if (
                direction == Direction.UP
                        && !state.canSurvive(level, pos)
        ) {
            return net.minecraft.world.level.block.Blocks.AIR
                    .defaultBlockState();
        }

        return super.updateShape(
                state,
                direction,
                neighbourState,
                level,
                pos,
                neighbourPos
        );
    }

    @Override
    protected InteractionResult useWithoutItem(
            BlockState state,
            Level level,
            BlockPos pos,
            Player player,
            BlockHitResult hit
    ) {
        /*
         * There is deliberately no normal right-click interaction.
         * Sneak-right-click keeps the mod's standard decor rotation control.
         */
        if (!player.isShiftKeyDown()) {
            return InteractionResult.PASS;
        }

        if (!level.isClientSide) {
            level.setBlock(
                    pos,
                    state.cycle(ROTATION),
                    3
            );
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

        if (!player.getAbilities().instabuild) {
            ItemStack stack =
                    DecorItems.POTTED_PLANT_CEILING
                            .get()
                            .getDefaultInstance();

            if (!player.getInventory().add(stack)) {
                popResource(level, pos, stack);
            }
        }

        level.removeBlock(pos, false);
    }

    @Override
    public PushReaction getPistonPushReaction(
            BlockState state
    ) {
        return PushReaction.DESTROY;
    }
}