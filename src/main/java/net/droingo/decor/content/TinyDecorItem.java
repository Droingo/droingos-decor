package net.droingo.decor.content;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.registry.DecorBlocks;
import net.minecraft.core.BlockPos;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.util.Mth;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.context.UseOnContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.state.BlockState;

public final class TinyDecorItem extends Item {
    private final ResourceLocation decorId;
    public TinyDecorItem(String id, Properties properties) { super(properties); this.decorId = ResourceLocation.fromNamespaceAndPath(DroingosDecor.MOD_ID, id); }
    @Override public InteractionResult useOn(UseOnContext context) {
        if (context.getClickedFace() != net.minecraft.core.Direction.UP) return InteractionResult.PASS;
        Level level = context.getLevel();
        BlockPos clickedPos = context.getClickedPos();
        BlockPos pos = level.getBlockState(clickedPos).is(DecorBlocks.DECOR_CONTAINER.get())
                ? clickedPos
                : clickedPos.above();
        BlockState state = level.getBlockState(pos);
        if (!state.isAir() && !state.is(DecorBlocks.DECOR_CONTAINER.get())) return InteractionResult.FAIL;
        double x = context.getClickLocation().x - context.getClickedPos().getX();
        double z = context.getClickLocation().z - context.getClickedPos().getZ();
        int slot = slotFromHit(x, z);
        int rotation = Mth.floor((context.getRotation() + 11.25F) / 22.5F) & 15;
        if (!level.isClientSide) {
            if (state.isAir()) level.setBlock(pos, DecorBlocks.DECOR_CONTAINER.get().defaultBlockState(), 3);
            if (!(level.getBlockEntity(pos) instanceof DecorContainerBlockEntity be) || !be.place(slot, decorId, rotation)) return InteractionResult.FAIL;
            if (context.getPlayer() == null || !context.getPlayer().getAbilities().instabuild) context.getItemInHand().shrink(1);
        }
        return InteractionResult.sidedSuccess(level.isClientSide);
    }
    public static int slotFromHit(double x, double z) { return (z >= 0.5 ? 2 : 0) + (x >= 0.5 ? 1 : 0); }
}
