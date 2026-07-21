package net.droingo.decor.content;

import net.droingo.decor.registry.DecorBlockEntities;
import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.protocol.game.ClientboundBlockEntityDataPacket;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

public final class FairyLightsTestBlockEntity extends BlockEntity {
    private Vec3 pointA = Vec3.ZERO;
    private Vec3 pointB = Vec3.ZERO;
    private FairyLightsMode mode = FairyLightsMode.STEADY;
    private double sag = 0.22D;

    public FairyLightsTestBlockEntity(BlockPos pos, BlockState state) {
        super(DecorBlockEntities.FAIRY_LIGHTS_TEST.get(), pos, state);
    }

    public void configure(
            Vec3 firstPoint,
            Vec3 secondPoint,
            boolean taut
    ) {
        pointA = firstPoint;
        pointB = secondPoint;
        sag = taut ? 0.08D : 0.22D;
        sync();
    }

    public Vec3 pointA() {
        return pointA;
    }

    public Vec3 pointB() {
        return pointB;
    }

    public FairyLightsMode mode() {
        return mode;
    }

    public double sag() {
        return sag;
    }

    public void cycleMode() {
        mode = mode.next();
        sync();
    }

    public void adjustSag(double amount) {
        sag += amount;
        if (sag < 0.04D) {
            sag = 0.32D;
        } else if (sag > 0.32D) {
            sag = 0.04D;
        }
        sync();
    }

    public boolean configured() {
        return pointA.distanceToSqr(pointB) > 0.01D;
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
        tag.putDouble("PointAX", pointA.x);
        tag.putDouble("PointAY", pointA.y);
        tag.putDouble("PointAZ", pointA.z);
        tag.putDouble("PointBX", pointB.x);
        tag.putDouble("PointBY", pointB.y);
        tag.putDouble("PointBZ", pointB.z);
        tag.putInt("Mode", mode.ordinal());
        tag.putDouble("Sag", sag);
    }

    @Override
    protected void loadAdditional(
            CompoundTag tag,
            HolderLookup.Provider registries
    ) {
        super.loadAdditional(tag, registries);
        pointA = new Vec3(
                tag.getDouble("PointAX"),
                tag.getDouble("PointAY"),
                tag.getDouble("PointAZ")
        );
        pointB = new Vec3(
                tag.getDouble("PointBX"),
                tag.getDouble("PointBY"),
                tag.getDouble("PointBZ")
        );
        mode = FairyLightsMode.byOrdinal(tag.getInt("Mode"));
        sag = tag.contains("Sag") ? tag.getDouble("Sag") : 0.22D;
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
}