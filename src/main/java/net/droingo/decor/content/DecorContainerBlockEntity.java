package net.droingo.decor.content;

import net.droingo.decor.registry.DecorBlockEntities;
import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.Connection;
import net.minecraft.network.protocol.game.ClientboundBlockEntityDataPacket;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;

public final class DecorContainerBlockEntity extends BlockEntity {
    private final ResourceLocation[] ids = new ResourceLocation[4];
    private final byte[] rotations = new byte[4];

    public DecorContainerBlockEntity(BlockPos pos, BlockState state) { super(DecorBlockEntities.DECOR_CONTAINER.get(), pos, state); }
    public boolean isEmpty(int slot) { return ids[slot] == null; }
    public boolean isCompletelyEmpty() { for (ResourceLocation id : ids) if (id != null) return false; return true; }
    public ResourceLocation getDecorId(int slot) { return ids[slot]; }
    public int getRotation(int slot) { return Byte.toUnsignedInt(rotations[slot]); }
    public boolean place(int slot, ResourceLocation id, int rotation) {
        if (!isEmpty(slot)) return false;
        ids[slot] = id; rotations[slot] = (byte)(rotation & 15); sync(); return true;
    }
    public ResourceLocation remove(int slot) { ResourceLocation old = ids[slot]; ids[slot] = null; rotations[slot] = 0; sync(); return old; }
    public void rotate(int slot) { if (ids[slot] != null) { rotations[slot] = (byte)((rotations[slot] + 1) & 15); sync(); } }
    private void sync() {
        setChanged();
        if (level != null && !level.isClientSide) level.sendBlockUpdated(worldPosition, getBlockState(), getBlockState(), 3);
    }
    @Override protected void saveAdditional(CompoundTag tag, HolderLookup.Provider registries) {
        super.saveAdditional(tag, registries);
        for (int i = 0; i < 4; i++) if (ids[i] != null) { tag.putString("Decor" + i, ids[i].toString()); tag.putByte("Rot" + i, rotations[i]); }
    }
    @Override protected void loadAdditional(CompoundTag tag, HolderLookup.Provider registries) {
        super.loadAdditional(tag, registries);
        for (int i = 0; i < 4; i++) { ids[i] = tag.contains("Decor" + i) ? ResourceLocation.tryParse(tag.getString("Decor" + i)) : null; rotations[i] = tag.getByte("Rot" + i); }
    }
    @Override public CompoundTag getUpdateTag(HolderLookup.Provider registries) { CompoundTag tag = super.getUpdateTag(registries); saveAdditional(tag, registries); return tag; }
    @Override public ClientboundBlockEntityDataPacket getUpdatePacket() { return ClientboundBlockEntityDataPacket.create(this); }
    @Override public void onDataPacket(Connection net, ClientboundBlockEntityDataPacket pkt, HolderLookup.Provider registries) { super.onDataPacket(net, pkt, registries); }
}
