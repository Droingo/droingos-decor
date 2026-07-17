package net.droingo.decor.content;

import com.mojang.serialization.MapCodec;
import net.droingo.decor.registry.DecorItems;
import net.minecraft.core.BlockPos;
import net.minecraft.resources.ResourceLocation;
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
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;
import org.jetbrains.annotations.Nullable;

public final class DecorContainerBlock extends BaseEntityBlock {
    public static final MapCodec<DecorContainerBlock> CODEC =
            simpleCodec(DecorContainerBlock::new);

    /*
     * Bounds of the Bobblehead Parrot relative to its placement point.
     *
     * These measurements include the new 1.5x renderer scale and are based
     * closely on the actual model dimensions.
     */
    private static final double PARROT_MIN_X = -0.118D;
    private static final double PARROT_MAX_X = 0.118D;

    private static final double PARROT_MIN_Z = -0.238D;
    private static final double PARROT_MAX_Z = 0.141D;

    private static final double PARROT_MIN_Y = 0.0D;
    private static final double PARROT_MAX_Y = 0.755D;

    public DecorContainerBlock(Properties properties) {
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
        return new DecorContainerBlockEntity(pos, state);
    }

    @Override
    protected VoxelShape getShape(
            BlockState state,
            BlockGetter level,
            BlockPos pos,
            CollisionContext context
    ) {
        return buildDecorShape(level, pos);
    }

    @Override
    protected VoxelShape getCollisionShape(
            BlockState state,
            BlockGetter level,
            BlockPos pos,
            CollisionContext context
    ) {
        return buildDecorShape(level, pos);
    }

    private VoxelShape buildDecorShape(BlockGetter level, BlockPos pos) {
        if (!(level.getBlockEntity(pos) instanceof DecorContainerBlockEntity blockEntity)) {
            return Shapes.empty();
        }

        VoxelShape combinedShape = Shapes.empty();

        for (int slot = 0; slot < 4; slot++) {
            ResourceLocation decorId = blockEntity.getDecorId(slot);

            if (decorId == null) {
                continue;
            }

            if (decorId.getPath().equals("bobble_parrot")) {
                VoxelShape parrotShape = createRotatedParrotShape(
                        slot,
                        blockEntity.getRotation(slot)
                );

                combinedShape = Shapes.or(combinedShape, parrotShape);
            }
        }

        return combinedShape.optimize();
    }

    private static VoxelShape createRotatedParrotShape(int slot, int rotationStep) {
        double centreX = slotCentreX(slot);
        double centreZ = slotCentreZ(slot);

        double angleRadians = Math.toRadians(rotationStep * 22.5D);
        double cos = Math.cos(angleRadians);
        double sin = Math.sin(angleRadians);

        double minX = Double.POSITIVE_INFINITY;
        double maxX = Double.NEGATIVE_INFINITY;
        double minZ = Double.POSITIVE_INFINITY;
        double maxZ = Double.NEGATIVE_INFINITY;

        double[] xCorners = {
                PARROT_MIN_X,
                PARROT_MAX_X
        };

        double[] zCorners = {
                PARROT_MIN_Z,
                PARROT_MAX_Z
        };

        for (double localX : xCorners) {
            for (double localZ : zCorners) {
                double rotatedX = localX * cos + localZ * sin;
                double rotatedZ = -localX * sin + localZ * cos;

                minX = Math.min(minX, centreX + rotatedX);
                maxX = Math.max(maxX, centreX + rotatedX);
                minZ = Math.min(minZ, centreZ + rotatedZ);
                maxZ = Math.max(maxZ, centreZ + rotatedZ);
            }
        }

        /*
         * Clamp inside the container block. This avoids tiny floating-point
         * errors producing coordinates just outside 0-1.
         */
        minX = clampToBlock(minX);
        maxX = clampToBlock(maxX);
        minZ = clampToBlock(minZ);
        maxZ = clampToBlock(maxZ);

        return Shapes.box(
                minX,
                PARROT_MIN_Y,
                minZ,
                maxX,
                PARROT_MAX_Y,
                maxZ
        );
    }

    private static double slotCentreX(int slot) {
        return slot % 2 == 0 ? 0.25D : 0.75D;
    }

    private static double slotCentreZ(int slot) {
        return slot < 2 ? 0.25D : 0.75D;
    }

    private static double clampToBlock(double value) {
        return Math.max(0.0D, Math.min(1.0D, value));
    }

    @Override
    protected InteractionResult useWithoutItem(
            BlockState state,
            Level level,
            BlockPos pos,
            Player player,
            BlockHitResult hit
    ) {
        if (!(level.getBlockEntity(pos) instanceof DecorContainerBlockEntity blockEntity)) {
            return InteractionResult.PASS;
        }

        int slot = TinyDecorItem.slotFromHit(
                hit.getLocation().x - pos.getX(),
                hit.getLocation().z - pos.getZ()
        );

        if (blockEntity.isEmpty(slot)) {
            return InteractionResult.PASS;
        }

        if (!level.isClientSide) {
            if (player.isShiftKeyDown()) {
                ResourceLocation removed = blockEntity.remove(slot);

                if (
                        removed != null
                                && removed.getPath().equals("bobble_parrot")
                                && !player.getAbilities().instabuild
                ) {
                    popResource(
                            level,
                            pos,
                            new ItemStack(DecorItems.BOBBLE_PARROT.get())
                    );
                }

                if (blockEntity.isCompletelyEmpty()) {
                    level.removeBlock(pos, false);
                }
            } else {
                blockEntity.rotate(slot);
            }
        }

        return InteractionResult.sidedSuccess(level.isClientSide);
    }
}