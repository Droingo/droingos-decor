package net.droingo.decor.content;

import com.mojang.serialization.MapCodec;
import net.droingo.decor.entity.BeastSkullSeatEntity;
import net.droingo.decor.registry.DecorEntities;
import net.droingo.decor.registry.DecorItems;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.LevelReader;
import net.minecraft.world.level.block.BaseEntityBlock;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.SupportType;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.entity.BlockEntityTicker;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.block.state.properties.DirectionProperty;
import net.minecraft.world.level.block.state.properties.EnumProperty;
import net.minecraft.world.level.block.state.properties.IntegerProperty;
import net.minecraft.world.level.material.PushReaction;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;
import org.jetbrains.annotations.Nullable;

public final class BeastSkullBlock extends BaseEntityBlock {
    public static final MapCodec<BeastSkullBlock> CODEC =
            simpleCodec(BeastSkullBlock::new);

    public static final DirectionProperty FACING =
            net.minecraft.world.level.block.HorizontalDirectionalBlock.FACING;

    public static final IntegerProperty ROTATION =
            BlockStateProperties.ROTATION_16;

    public static final EnumProperty<BeastSkullPlacement> PLACEMENT =
            EnumProperty.create(
                    "placement",
                    BeastSkullPlacement.class
            );

    private static final VoxelShape FLOOR_SHAPE =
            Shapes.box(
                    0.0D,
                    0.0D,
                    0.0D,
                    1.0D,
                    1.0D,
                    1.0D
            );

    private static final VoxelShape WALL_SHAPE =
            Shapes.box(
                    0.0D,
                    0.0D,
                    0.25D,
                    1.0D,
                    1.0D,
                    1.0D
            );

    private static final VoxelShape CEILING_SHAPE =
            Shapes.box(
                    0.0D,
                    0.0D,
                    0.0D,
                    1.0D,
                    1.0D,
                    1.0D
            );

    public BeastSkullBlock(Properties properties) {
        super(properties);

        registerDefaultState(
                stateDefinition.any()
                        .setValue(
                                FACING,
                                Direction.NORTH
                        )
                        .setValue(
                                ROTATION,
                                0
                        )
                        .setValue(
                                PLACEMENT,
                                BeastSkullPlacement.FLOOR
                        )
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
        builder.add(
                FACING,
                ROTATION,
                PLACEMENT
        );
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
        return new BeastSkullBlockEntity(pos, state);
    }

    @Nullable
    @Override
    public <T extends BlockEntity>
    BlockEntityTicker<T> getTicker(
            Level level,
            BlockState state,
            BlockEntityType<T> type
    ) {
        return createTickerHelper(
                type,
                net.droingo.decor.registry
                        .DecorBlockEntities
                        .BEAST_SKULL
                        .get(),
                BeastSkullBlockEntity::serverTick
        );
    }

    @Override
    protected VoxelShape getShape(
            BlockState state,
            BlockGetter level,
            BlockPos pos,
            CollisionContext context
    ) {
        return switch (
                state.getValue(PLACEMENT)
        ) {
            case FLOOR -> FLOOR_SHAPE;
            case WALL -> WALL_SHAPE;
            case CEILING -> CEILING_SHAPE;
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
    protected boolean canSurvive(
            BlockState state,
            LevelReader level,
            BlockPos pos
    ) {
        return switch (
                state.getValue(PLACEMENT)
        ) {
            case FLOOR ->
                    sturdy(
                            level,
                            pos.below(),
                            Direction.UP
                    );

            case CEILING ->
                    sturdy(
                            level,
                            pos.above(),
                            Direction.DOWN
                    );

            case WALL -> {
                Direction outward =
                        state.getValue(FACING);

                Direction supportDirection =
                        outward.getOpposite();

                yield sturdy(
                        level,
                        pos.relative(supportDirection),
                        outward
                );
            }
        };
    }

    private static boolean sturdy(
            LevelReader level,
            BlockPos supportPos,
            Direction face
    ) {
        return level.getBlockState(supportPos)
                .isFaceSturdy(
                        level,
                        supportPos,
                        face,
                        SupportType.CENTER
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
        BeastSkullPlacement placement =
                state.getValue(PLACEMENT);

        if (player.isShiftKeyDown()) {
            if (placement == BeastSkullPlacement.WALL) {
                return InteractionResult.PASS;
            }

            if (!level.isClientSide) {
                level.setBlock(
                        pos,
                        state.cycle(ROTATION),
                        3
                );
            }

            return InteractionResult.sidedSuccess(
                    level.isClientSide
            );
        }

        if (
                !(level.getBlockEntity(pos)
                        instanceof BeastSkullBlockEntity skull)
        ) {
            return InteractionResult.PASS;
        }

        if (placement != BeastSkullPlacement.FLOOR) {
            if (!level.isClientSide) {
                skull.triggerSnap();
            }

            return InteractionResult.sidedSuccess(
                    level.isClientSide
            );
        }

        if (
                !level.isClientSide
                        && level
                        instanceof net.minecraft.server.level
                        .ServerLevel server
        ) {
            BeastSkullSeatEntity seat =
                    skull.findSeat(server);

            if (seat != null && seat.isVehicle()) {
                return InteractionResult.CONSUME;
            }

            if (seat == null) {
                seat = new BeastSkullSeatEntity(
                        DecorEntities.BEAST_SKULL_SEAT.get(),
                        level
                );

                seat.setParent(
                        pos,
                        state.getValue(FACING)
                );

                seat.moveTo(
                        pos.getX() + 0.5D,
                        pos.getY() + 0.66D,
                        pos.getZ() + 0.5D,
                        state.getValue(FACING).toYRot(),
                        0.0F
                );

                level.addFreshEntity(seat);
            }

            if (player.startRiding(seat, true)) {
                skull.beginChewing();
            }
        }

        return InteractionResult.sidedSuccess(
                level.isClientSide
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

        if (level.isClientSide) {
            return;
        }

        if (
                level.getBlockEntity(pos)
                        instanceof BeastSkullBlockEntity skull
        ) {
            skull.ejectAndRemoveSeat();
        }

        if (!player.getAbilities().instabuild) {
            ItemStack stack =
                    DecorItems.THE_BEAST_SKULL
                            .get()
                            .getDefaultInstance();

            if (!player.getInventory().add(stack)) {
                popResource(level, pos, stack);
            }
        }

        level.removeBlock(pos, false);
    }

    @Override
    protected void onRemove(
            BlockState state,
            Level level,
            BlockPos pos,
            BlockState newState,
            boolean movedByPiston
    ) {
        if (
                !state.is(newState.getBlock())
                        && level.getBlockEntity(pos)
                        instanceof BeastSkullBlockEntity skull
        ) {
            skull.ejectAndRemoveSeat();
        }

        super.onRemove(
                state,
                level,
                pos,
                newState,
                movedByPiston
        );
    }

    @Override
    public PushReaction getPistonPushReaction(
            BlockState state
    ) {
        return PushReaction.DESTROY;
    }
}