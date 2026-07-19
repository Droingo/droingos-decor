package net.droingo.decor.content;

import net.droingo.decor.entity.BeastSkullSeatEntity;
import net.droingo.decor.registry.DecorBlockEntities;
import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.protocol.game.ClientboundBlockEntityDataPacket;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

import java.util.List;

public final class BeastSkullBlockEntity extends BlockEntity {
    public static final byte ANIMATION_NONE = 0;
    public static final byte ANIMATION_SNAP = 1;
    public static final byte ANIMATION_CHEW = 2;
    public static final byte ANIMATION_HARD_BITE = 3;

    private static final int CHEW_PERIOD = 24;
    private static final float SPIT_CHANCE = 0.04F;
    private static final float BITE_CHANCE = 0.02F;
    private static final float BITE_DAMAGE = 6.0F;

    private byte animation = ANIMATION_NONE;
    private long animationStart = Long.MIN_VALUE;
    private long lastChewCycle = Long.MIN_VALUE;

    public BeastSkullBlockEntity(BlockPos pos, BlockState state) {
        super(DecorBlockEntities.BEAST_SKULL.get(), pos, state);
    }

    public byte animation() { return animation; }
    public long animationStart() { return animationStart; }

    public void triggerSnap() {
        if (level == null) return;
        animation = ANIMATION_SNAP;
        animationStart = level.getGameTime();
        sync();
    }

    public void beginChewing() {
        if (level == null) return;
        animation = ANIMATION_CHEW;
        animationStart = level.getGameTime();
        lastChewCycle = -1L;
        sync();
    }

    public static void serverTick(Level level, BlockPos pos, BlockState state, BeastSkullBlockEntity be) {
        if (!(level instanceof ServerLevel server)) return;
        if (state.getValue(BeastSkullBlock.PLACEMENT) != BeastSkullPlacement.FLOOR) return;

        BeastSkullSeatEntity seat = be.findSeat(server);
        if (seat == null || !seat.isVehicle()) {
            if (be.animation == ANIMATION_CHEW) {
                be.animation = ANIMATION_NONE;
                be.sync();
            }
            return;
        }

        if (be.animation != ANIMATION_CHEW) be.beginChewing();
        long cycle = Math.max(0L, (level.getGameTime() - be.animationStart) / CHEW_PERIOD);
        if (cycle == be.lastChewCycle) return;
        be.lastChewCycle = cycle;
        if (cycle == 0L) return;

        float roll = level.random.nextFloat();
        if (roll < BITE_CHANCE) {
            Entity passenger = seat.getFirstPassenger();
            be.animation = ANIMATION_HARD_BITE;
            be.animationStart = level.getGameTime();
            be.sync();
            if (passenger instanceof LivingEntity living) {
                living.hurt(level.damageSources().generic(), BITE_DAMAGE);
            }
            be.eject(seat, passenger, 0.45D, 0.18D);
        } else if (roll < BITE_CHANCE + SPIT_CHANCE) {
            Entity passenger = seat.getFirstPassenger();
            be.eject(seat, passenger, 1.15D, 0.45D);
        }
    }

    private void eject(BeastSkullSeatEntity seat, Entity passenger, double forward, double upward) {
        if (passenger == null) return;
        passenger.stopRiding();
        float yaw = getBlockState().getValue(BeastSkullBlock.FACING).toYRot();
        double radians = Math.toRadians(yaw);
        Vec3 launch = new Vec3(-Math.sin(radians) * forward, upward, Math.cos(radians) * forward);
        passenger.setDeltaMovement(launch);
        passenger.hurtMarked = true;
        seat.discard();
    }

    public BeastSkullSeatEntity findSeat(ServerLevel level) {
        AABB box = new AABB(worldPosition).inflate(2.0D);
        List<BeastSkullSeatEntity> seats = level.getEntitiesOfClass(
                BeastSkullSeatEntity.class,
                box,
                seat -> seat.parentPos().equals(worldPosition)
        );
        return seats.isEmpty() ? null : seats.getFirst();
    }

    public void ejectAndRemoveSeat() {
        if (!(level instanceof ServerLevel server)) return;
        BeastSkullSeatEntity seat = findSeat(server);
        if (seat != null) {
            seat.ejectPassengers();
            seat.discard();
        }
    }

    private void sync() {
        setChanged();
        if (level != null && !level.isClientSide) {
            level.sendBlockUpdated(worldPosition, getBlockState(), getBlockState(), 3);
        }
    }

    @Override protected void saveAdditional(CompoundTag tag, HolderLookup.Provider registries) {
        super.saveAdditional(tag, registries);
        tag.putByte("Animation", animation);
        tag.putLong("AnimationStart", animationStart);
    }

    @Override protected void loadAdditional(CompoundTag tag, HolderLookup.Provider registries) {
        super.loadAdditional(tag, registries);
        animation = tag.getByte("Animation");
        animationStart = tag.contains("AnimationStart") ? tag.getLong("AnimationStart") : Long.MIN_VALUE;
    }

    @Override public CompoundTag getUpdateTag(HolderLookup.Provider registries) {
        CompoundTag tag = super.getUpdateTag(registries);
        saveAdditional(tag, registries);
        return tag;
    }

    @Override public ClientboundBlockEntityDataPacket getUpdatePacket() {
        return ClientboundBlockEntityDataPacket.create(this);
    }
}
