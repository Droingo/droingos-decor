package net.droingo.decor.content;

import com.mojang.serialization.MapCodec;
import net.droingo.decor.registry.DecorItems;
import net.minecraft.core.BlockPos;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
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

public final class DecorContainerBlock extends BaseEntityBlock {
    public static final MapCodec<DecorContainerBlock> CODEC =
            simpleCodec(DecorContainerBlock::new);

    /*
     * Bobblehead Parrot bounds relative to its selected quarter-block slot.
     * These account for the current 1.5x render scale.
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

    /*
     * The invisible container should not itself be mined.
     *
     * Individual decorations are removed through attack(), allowing one
     * decoration to be picked up without destroying every other decoration
     * sharing this block position.
     */
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

            if (isBobbleParrot(decorId)) {
                VoxelShape parrotShape = createRotatedParrotShape(
                        slot,
                        blockEntity.getRotation(slot)
                );

                combinedShape = Shapes.or(combinedShape, parrotShape);
            }
        }

        return combinedShape.optimize();
    }

    private static VoxelShape createRotatedParrotShape(
            int slot,
            int rotationStep
    ) {
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

    /*
     * Empty-hand right-click interaction.
     *
     * Shift-right-click rotates the selected decoration.
     * Ordinary right-click activates that decoration's custom interaction.
     */
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

        int slot = slotFromHit(pos, hit);

        ResourceLocation decorId = blockEntity.getDecorId(slot);

        if (decorId == null) {
            return InteractionResult.PASS;
        }

        if (player.isShiftKeyDown()) {
            if (!level.isClientSide) {
                blockEntity.rotate(slot);
            }

            return InteractionResult.sidedSuccess(level.isClientSide);
        }

        if (!level.isClientSide) {
            interactWithDecor(
                    level,
                    pos,
                    player,
                    decorId
            );
        }

        return InteractionResult.sidedSuccess(level.isClientSide);
    }

    /*
     * Punching removes only the decoration under the crosshair.
     *
     * The player's look ray is used here because Block.attack does not receive
     * the original BlockHitResult.
     */
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

        if (!(level.getBlockEntity(pos) instanceof DecorContainerBlockEntity blockEntity)) {
            return;
        }

        HitResult pickedResult = player.pick(
                5.0D,
                1.0F,
                false
        );

        if (!(pickedResult instanceof BlockHitResult blockHit)) {
            return;
        }

        if (!blockHit.getBlockPos().equals(pos)) {
            return;
        }

        int slot = slotFromHit(pos, blockHit);

        ResourceLocation decorId = blockEntity.getDecorId(slot);

        if (decorId == null) {
            return;
        }

        removeAndReturnDecor(
                level,
                pos,
                player,
                blockEntity,
                slot,
                decorId
        );
    }

    private static int slotFromHit(
            BlockPos pos,
            BlockHitResult hit
    ) {
        return TinyDecorItem.slotFromHit(
                hit.getLocation().x - pos.getX(),
                hit.getLocation().z - pos.getZ()
        );
    }

    private static void interactWithDecor(
            Level level,
            BlockPos pos,
            Player player,
            ResourceLocation decorId
    ) {
        if (isBobbleParrot(decorId)) {
            /*
             * Vanilla does not have a separate baby-parrot sound event.
             * Raising the pitch of the normal parrot ambient sound gives it
             * the small, squeaky baby-parrot character.
             */
            float pitch = 1.45F + level.random.nextFloat() * 0.25F;

            level.playSound(
                    null,
                    pos,
                    SoundEvents.PARROT_AMBIENT,
                    SoundSource.BLOCKS,
                    0.85F,
                    pitch
            );
        }
    }

    private static void removeAndReturnDecor(
            Level level,
            BlockPos pos,
            Player player,
            DecorContainerBlockEntity blockEntity,
            int slot,
            ResourceLocation decorId
    ) {
        ResourceLocation removed = blockEntity.remove(slot);

        if (removed == null) {
            return;
        }

        ItemStack returnedStack = getDecorItem(removed);

        if (
                !returnedStack.isEmpty()
                        && !player.getAbilities().instabuild
        ) {
            /*
             * Prefer returning the decoration directly to the player's
             * inventory. Drop it into the world only when the inventory is full.
             */
            if (!player.getInventory().add(returnedStack)) {
                popResource(
                        level,
                        pos,
                        returnedStack
                );
            }
        }

        if (blockEntity.isCompletelyEmpty()) {
            level.removeBlock(pos, false);
        }
    }

    private static ItemStack getDecorItem(ResourceLocation decorId) {
        if (isBobbleParrot(decorId)) {
            return new ItemStack(
                    DecorItems.BOBBLE_PARROT.get()
            );
        }

        return ItemStack.EMPTY;
    }

    private static boolean isBobbleParrot(ResourceLocation decorId) {
        return decorId.getNamespace().equals("droingos_decor")
                && decorId.getPath().equals("bobble_parrot");
    }
}