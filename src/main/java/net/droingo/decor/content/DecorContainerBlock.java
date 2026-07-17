package net.droingo.decor.content;

import com.mojang.serialization.MapCodec;
import net.droingo.decor.api.DecorDefinition;
import net.droingo.decor.registry.DecorDefinitionRegistry;
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
import net.minecraft.world.phys.HitResult;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;
import org.jetbrains.annotations.Nullable;

public final class DecorContainerBlock extends BaseEntityBlock {
    public static final MapCodec<DecorContainerBlock> CODEC = simpleCodec(DecorContainerBlock::new);

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
    protected float getDestroyProgress(BlockState state, Player player, BlockGetter level, BlockPos pos) {
        return 0.0F;
    }

    @Override
    protected VoxelShape getShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context) {
        return buildDecorShape(level, pos);
    }

    @Override
    protected VoxelShape getCollisionShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context) {
        return buildDecorShape(level, pos);
    }

    private VoxelShape buildDecorShape(BlockGetter level, BlockPos pos) {
        if (!(level.getBlockEntity(pos) instanceof DecorContainerBlockEntity container)) {
            return Shapes.empty();
        }

        VoxelShape combined = Shapes.empty();

        for (int slot = 0; slot < 4; slot++) {
            ResourceLocation id = container.getDecorId(slot);
            DecorDefinition definition = id == null ? null : DecorDefinitionRegistry.get(id);

            if (definition != null) {
                combined = Shapes.or(combined, DecorShapes.rotatedTinyShape(
                        definition,
                        slot,
                        container.getRotation(slot)
                ));
            }
        }

        return combined.optimize();
    }

    @Override
    protected InteractionResult useWithoutItem(
            BlockState state,
            Level level,
            BlockPos pos,
            Player player,
            BlockHitResult hit
    ) {
        if (!(level.getBlockEntity(pos) instanceof DecorContainerBlockEntity container)) {
            return InteractionResult.PASS;
        }

        int slot = slotFromHit(pos, hit);
        ResourceLocation id = container.getDecorId(slot);
        DecorDefinition definition = id == null ? null : DecorDefinitionRegistry.get(id);

        if (definition == null) {
            return InteractionResult.PASS;
        }

        if (player.isShiftKeyDown()) {
            if (!level.isClientSide) {
                container.rotate(slot);
            }
            return InteractionResult.sidedSuccess(level.isClientSide);
        }

        return definition.interaction().interact(level, pos, player, container, slot);
    }

    @Override
    public void attack(BlockState state, Level level, BlockPos pos, Player player) {
        super.attack(state, level, pos, player);

        if (level.isClientSide || !(level.getBlockEntity(pos) instanceof DecorContainerBlockEntity container)) {
            return;
        }

        HitResult picked = player.pick(5.0D, 1.0F, false);
        if (!(picked instanceof BlockHitResult blockHit) || !blockHit.getBlockPos().equals(pos)) {
            return;
        }

        int slot = slotFromHit(pos, blockHit);
        ResourceLocation id = container.getDecorId(slot);
        DecorDefinition definition = id == null ? null : DecorDefinitionRegistry.get(id);

        if (definition == null || container.remove(slot) == null) {
            return;
        }

        if (!player.getAbilities().instabuild) {
            ItemStack stack = definition.pickupStack();
            if (!player.getInventory().add(stack)) {
                popResource(level, pos, stack);
            }
        }

        if (container.isCompletelyEmpty()) {
            level.removeBlock(pos, false);
        }
    }

    private static int slotFromHit(BlockPos pos, BlockHitResult hit) {
        return TinyDecorItem.slotFromHit(
                hit.getLocation().x - pos.getX(),
                hit.getLocation().z - pos.getZ()
        );
    }
}