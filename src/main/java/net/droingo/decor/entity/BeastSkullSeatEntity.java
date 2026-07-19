package net.droingo.decor.entity;

import net.droingo.decor.content.BeastSkullBlock;
import net.droingo.decor.content.BeastSkullPlacement;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.Pose;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;

public final class BeastSkullSeatEntity extends Entity {
    private BlockPos parentPos = BlockPos.ZERO;
    private Direction facing = Direction.NORTH;

    public BeastSkullSeatEntity(
            EntityType<? extends BeastSkullSeatEntity> type,
            Level level
    ) {
        super(type, level);
        noPhysics = true;
        setNoGravity(true);
    }

    public void setParent(BlockPos pos, Direction facing) {
        this.parentPos = pos.immutable();
        this.facing = facing;

        setYRot(facing.toYRot());
        setYHeadRot(facing.toYRot());
    }

    public BlockPos parentPos() {
        return parentPos;
    }

    @Override
    protected void defineSynchedData(
            SynchedEntityData.Builder builder
    ) {
    }

    @Override
    public void tick() {
        super.tick();

        noPhysics = true;
        setNoGravity(true);

        /*
         * Apply the crawl pose every tick on both logical sides. A normal
         * passenger can be reset to the riding pose by Player tick logic, so
         * doing this only inside positionRider is not persistent enough.
         */
        for (Entity passenger : getPassengers()) {
            passenger.setPose(Pose.SWIMMING);
        }

        if (!level().isClientSide) {
            var state = level().getBlockState(parentPos);

            if (!(state.getBlock() instanceof BeastSkullBlock)
                    || state.getValue(BeastSkullBlock.PLACEMENT)
                    != BeastSkullPlacement.FLOOR
                    || !isVehicle()) {
                restorePassengerPoses();
                discard();
            }
        }
    }

    @Override
    protected boolean canAddPassenger(Entity passenger) {
        return passenger instanceof Player
                && getPassengers().isEmpty();
    }

    /*
     * Prevent Minecraft from forcing the ordinary seated/riding model pose.
     * The passenger is instead held in Pose.SWIMMING above.
     */
    @Override
    public boolean shouldRiderSit() {
        return false;
    }

    @Override
    protected void positionRider(
            Entity passenger,
            MoveFunction move
    ) {
        if (!hasPassenger(passenger)) {
            return;
        }

        double yaw = Math.toRadians(getYRot());
        double forward = 0.10D;

        double x =
                getX()
                        - Math.sin(yaw) * forward;

        double z =
                getZ()
                        + Math.cos(yaw) * forward;

        double y = getY() - 0.03D;

        move.accept(passenger, x, y, z);

        /*
         * Do not overwrite passenger yaw or head yaw here. Doing so every
         * frame made the player's mouse feel locked to the skull direction.
         */
        passenger.setPose(Pose.SWIMMING);
    }

    @Override
    protected void removePassenger(Entity passenger) {
        super.removePassenger(passenger);
        passenger.setPose(Pose.STANDING);
    }

    private void restorePassengerPoses() {
        for (Entity passenger : getPassengers()) {
            passenger.setPose(Pose.STANDING);
        }

        ejectPassengers();
    }

    @Override
    public Vec3 getDismountLocationForPassenger(
            net.minecraft.world.entity.LivingEntity passenger
    ) {
        double yaw = Math.toRadians(getYRot());

        return new Vec3(
                getX()
                        - Math.sin(yaw) * 1.25D,
                getY() - 0.46D,
                getZ()
                        + Math.cos(yaw) * 1.25D
        );
    }

    @Override
    protected void readAdditionalSaveData(CompoundTag tag) {
        parentPos = BlockPos.of(tag.getLong("Parent"));
        facing = Direction.from2DDataValue(
                tag.getInt("Facing")
        );

        setYRot(facing.toYRot());
        setYHeadRot(facing.toYRot());
    }

    @Override
    protected void addAdditionalSaveData(CompoundTag tag) {
        tag.putLong("Parent", parentPos.asLong());
        tag.putInt(
                "Facing",
                facing.get2DDataValue()
        );
    }

    @Override
    public boolean isPickable() {
        return false;
    }

    @Override
    public boolean isPushable() {
        return false;
    }
}