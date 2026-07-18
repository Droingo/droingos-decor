package net.droingo.decor.content;

import net.droingo.decor.registry.DecorBlockEntities;
import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.Connection;
import net.minecraft.network.protocol.game.ClientboundBlockEntityDataPacket;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;

public final class HalfDecorBlockEntity extends BlockEntity {
    private byte rotation;
    private long animationStartTick = Long.MIN_VALUE;

    public HalfDecorBlockEntity(BlockPos pos, BlockState state) {
        super(
                DecorBlockEntities.HALF_DECOR_CONTAINER.get(),
                pos,
                state
        );
    }

    public int getRotation() {
        return Byte.toUnsignedInt(rotation);
    }

    public long getAnimationStartTick() {
        return animationStartTick;
    }

    public void rotate() {
        rotation = (byte) ((rotation + 1) & 15);
        sync();
    }

    public void startPlayAnimation() {
        if (level == null) {
            return;
        }

        animationStartTick = level.getGameTime();
        sync();
    }

    private void sync() {
        setChanged();

        if (level != null && !level.isClientSide) {
            level.sendBlockUpdated(
                    worldPosition,
                    getBlockState(),
                    getBlockState(),
                    3
            );
        }
    }

    @Override
    protected void saveAdditional(
            CompoundTag tag,
            HolderLookup.Provider registries
    ) {
        super.saveAdditional(tag, registries);
        tag.putByte("Rotation", rotation);
        tag.putLong("AnimationStart", animationStartTick);
    }

    @Override
    protected void loadAdditional(
            CompoundTag tag,
            HolderLookup.Provider registries
    ) {
        super.loadAdditional(tag, registries);
        rotation = tag.getByte("Rotation");
        animationStartTick = tag.contains("AnimationStart")
                ? tag.getLong("AnimationStart")
                : Long.MIN_VALUE;
    }

    @Override
    public CompoundTag getUpdateTag(
            HolderLookup.Provider registries
    ) {
        CompoundTag tag = super.getUpdateTag(registries);
        saveAdditional(tag, registries);
        return tag;
    }

    @Override
    public ClientboundBlockEntityDataPacket getUpdatePacket() {
        return ClientboundBlockEntityDataPacket.create(this);
    }

    @Override
    public void onDataPacket(
            Connection net,
            ClientboundBlockEntityDataPacket packet,
            HolderLookup.Provider registries
    ) {
        super.onDataPacket(net, packet, registries);
    }
}