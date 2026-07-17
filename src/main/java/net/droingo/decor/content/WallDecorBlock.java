package net.droingo.decor.content;

import com.mojang.serialization.MapCodec;
import net.droingo.decor.api.DecorDefinition;
import net.droingo.decor.registry.DecorDefinitionRegistry;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.BaseEntityBlock;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.block.state.properties.DirectionProperty;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;
import org.jetbrains.annotations.Nullable;

public final class WallDecorBlock extends BaseEntityBlock {
    public static final MapCodec<WallDecorBlock> CODEC =
            simpleCodec(WallDecorBlock::new);

    public static final DirectionProperty FACING =
            BlockStateProperties.HORIZONTAL_FACING;

    private static final VoxelShape NORTH_SHAPE =
            Shapes.box(0.0D, 0.0D, 0.0D, 1.0D, 1.0D, 2.0D / 16.0D);

    private static final VoxelShape SOUTH_SHAPE =
            Shapes.box(0.0D, 0.0D, 14.0D / 16.0D, 1.0D, 1.0D, 1.0D);

    private static final VoxelShape WEST_SHAPE =
            Shapes.box(0.0D, 0.0D, 0.0D, 2.0D / 16.0D, 1.0D, 1.0D);

    private static final VoxelShape EAST_SHAPE =
            Shapes.box(14.0D / 16.0D, 0.0D, 0.0D, 1.0D, 1.0D, 1.0D);

    public WallDecorBlock(Properties properties) {
        super(properties);
        registerDefaultState(stateDefinition.any().setValue(FACING, Direction.SOUTH));
    }

    @Override
    protected MapCodec<? extends BaseEntityBlock> codec() {
        return CODEC;
    }

    @Override
    protected void createBlockStateDefinition(
            StateDefinition.Builder<net.minecraft.world.level.block.Block, BlockState> builder
    ) {
        builder.add(FACING);
    }

    @Override
    public RenderShape getRenderShape(BlockState state) {
        return RenderShape.INVISIBLE;
    }

    @Nullable
    @Override
    public BlockEntity newBlockEntity(BlockPos pos, BlockState state) {
        return new WallDecorBlockEntity(pos, state);
    }

    @Override
    protected float getDestroyProgress(
            BlockState state,
            Player player,
            BlockGetter level,
            BlockPos pos
    ) {
        return 0.0F;
    }

    @Override
    protected VoxelShape getShape(
            BlockState state,
            BlockGetter level,
            BlockPos pos,
            CollisionContext context
    ) {
        return switch (state.getValue(FACING)) {
            case NORTH -> NORTH_SHAPE;
            case SOUTH -> SOUTH_SHAPE;
            case WEST -> WEST_SHAPE;
            case EAST -> EAST_SHAPE;
            default -> SOUTH_SHAPE;
        };
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
    protected InteractionResult useWithoutItem(
            BlockState state,
            Level level,
            BlockPos pos,
            Player player,
            BlockHitResult hit
    ) {
        if (!(level.getBlockEntity(pos) instanceof WallDecorBlockEntity blockEntity)) {
            return InteractionResult.PASS;
        }

        DecorDefinition definition = blockEntity.getDecorId() == null
                ? null
                : DecorDefinitionRegistry.get(blockEntity.getDecorId());

        if (definition == null) {
            return InteractionResult.PASS;
        }

        /*
         * Wall decor has a fixed mounting direction, so sneak-use does not
         * rotate it. Normal use runs the decoration's own interaction.
         */
        if (player.isShiftKeyDown()) {
            return InteractionResult.sidedSuccess(level.isClientSide);
        }

        return definition.interaction().interact(
                level,
                pos,
                player,
                null,
                0
        );
    }

    @Override
    public void attack(
            BlockState state,
            Level level,
            BlockPos pos,
            Player player
    ) {
        super.attack(state, level, pos, player);

        if (
                level.isClientSide
                        || !(level.getBlockEntity(pos)
                        instanceof WallDecorBlockEntity blockEntity)
        ) {
            return;
        }

        DecorDefinition definition = blockEntity.getDecorId() == null
                ? null
                : DecorDefinitionRegistry.get(blockEntity.getDecorId());

        if (definition != null && !player.getAbilities().instabuild) {
            ItemStack stack = definition.pickupStack();

            if (!player.getInventory().add(stack)) {
                popResource(level, pos, stack);
            }
        }

        level.removeBlock(pos, false);
    }
}