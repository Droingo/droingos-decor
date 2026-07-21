package net.droingo.decor.content;

import net.droingo.decor.registry.DecorBlockEntities;
import net.droingo.decor.registry.DecorBlocks;
import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.nbt.Tag;
import net.minecraft.network.protocol.game.ClientboundBlockEntityDataPacket;
import net.minecraft.world.item.DyeColor;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

public final class FairyLightsTestBlockEntity extends BlockEntity {
    private static final String CONNECTIONS = "Connections";
    private static final double SLOT_MATCH_DISTANCE_SQUARED = 0.08D * 0.08D;

    private final List<Connection> connections = new ArrayList<>();

    public FairyLightsTestBlockEntity(BlockPos pos, BlockState state) {
        super(DecorBlockEntities.FAIRY_LIGHTS_TEST.get(), pos, state);
    }

    public void addConnectionRecord(Connection connection) {
        if (findById(connection.id()) != null) {
            return;
        }

        connections.add(connection.copy());
        sync();
    }

    public List<Connection> connections() {
        return Collections.unmodifiableList(connections);
    }

    public boolean configured() {
        return !connections.isEmpty();
    }

    public Vec3 localMountPoint(Connection connection) {
        if (worldPosition.equals(connection.anchorA())) {
            return connection.pointA();
        }
        return connection.pointB();
    }

    public BlockPos remoteAnchor(Connection connection) {
        if (worldPosition.equals(connection.anchorA())) {
            return connection.anchorB();
        }
        return connection.anchorA();
    }

    public int countAt(Vec3 point) {
        Vec3 target = nearestMountPoint(point);
        if (target == null) {
            return 0;
        }

        int count = 0;
        for (Connection connection : connections) {
            if (sameMount(localMountPoint(connection), target)) {
                count++;
            }
        }
        return count;
    }

    public FairyLightsMode modeAt(Vec3 point) {
        Connection connection = nearestConnection(point);
        return connection == null
                ? FairyLightsMode.STEADY
                : connection.mode();
    }

    public double sagAt(Vec3 point) {
        Connection connection = nearestConnection(point);
        return connection == null ? 0.22D : connection.sag();
    }

    public void cycleModeAt(Vec3 point) {
        Vec3 target = nearestMountPoint(point);
        Connection nearest = nearestConnection(point);

        if (target == null || nearest == null) {
            return;
        }

        FairyLightsMode next = nearest.mode().next();

        for (Connection connection : connections) {
            if (sameMount(localMountPoint(connection), target)) {
                connection.setMode(next);
                pushStateToOtherEnd(connection);
            }
        }

        sync();
    }

    public void adjustSagAt(Vec3 point, double amount) {
        Vec3 target = nearestMountPoint(point);
        if (target == null) {
            return;
        }

        for (Connection connection : connections) {
            if (sameMount(localMountPoint(connection), target)) {
                connection.adjustSag(amount);
                pushStateToOtherEnd(connection);
            }
        }

        sync();
    }

    public void dyeAt(Vec3 point, DyeColor color) {
        Vec3 target = nearestMountPoint(point);
        if (target == null) {
            return;
        }

        for (Connection connection : connections) {
            if (sameMount(localMountPoint(connection), target)) {
                connection.setColor(color);
                pushStateToOtherEnd(connection);
            }
        }

        sync();
    }

    public Vec3 nearestMountPoint(Vec3 point) {
        Connection connection = nearestConnection(point);
        return connection == null ? null : localMountPoint(connection);
    }

    private Connection nearestConnection(Vec3 point) {
        Connection nearest = null;
        double bestDistance = Double.POSITIVE_INFINITY;

        for (Connection connection : connections) {
            double distance = localMountPoint(connection).distanceToSqr(point);
            if (distance < bestDistance) {
                bestDistance = distance;
                nearest = connection;
            }
        }

        return nearest;
    }

    private static boolean sameMount(Vec3 first, Vec3 second) {
        return first.distanceToSqr(second) <= SLOT_MATCH_DISTANCE_SQUARED;
    }

    private Connection findById(UUID id) {
        for (Connection connection : connections) {
            if (connection.id().equals(id)) {
                return connection;
            }
        }
        return null;
    }

    private void receiveState(
            UUID id,
            FairyLightsMode mode,
            double sag,
            DyeColor color
    ) {
        Connection connection = findById(id);
        if (connection == null) {
            return;
        }

        connection.setMode(mode);
        connection.setSag(sag);
        connection.setColor(color);
        sync();
    }

    private void pushStateToOtherEnd(Connection connection) {
        if (level == null || level.isClientSide) {
            return;
        }

        BlockPos remote = remoteAnchor(connection);
        if (level.getBlockEntity(remote)
                instanceof FairyLightsTestBlockEntity other) {
            other.receiveState(
                    connection.id(),
                    connection.mode(),
                    connection.sag(),
                    connection.color()
            );
        }
    }

    public void detachAllFromRemoteAnchors() {
        if (level == null || level.isClientSide || connections.isEmpty()) {
            return;
        }

        List<Connection> snapshot = new ArrayList<>(connections);

        for (Connection connection : snapshot) {
            BlockPos remote = remoteAnchor(connection);

            if (level.getBlockEntity(remote)
                    instanceof FairyLightsTestBlockEntity other) {
                other.removeConnectionFromPartner(connection.id());

                if (!other.configured()
                        && level.getBlockState(remote)
                        .is(DecorBlocks.FAIRY_LIGHTS_TEST)) {
                    level.removeBlock(remote, false);
                }
            }
        }

        connections.clear();
        setChanged();
    }

    private void removeConnectionFromPartner(UUID id) {
        connections.removeIf(connection -> connection.id().equals(id));
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

        ListTag list = new ListTag();

        for (Connection connection : connections) {
            CompoundTag entry = new CompoundTag();
            entry.putUUID("Id", connection.id());
            entry.putLong("AnchorA", connection.anchorA().asLong());
            entry.putLong("AnchorB", connection.anchorB().asLong());
            entry.putDouble("PointAX", connection.pointA().x);
            entry.putDouble("PointAY", connection.pointA().y);
            entry.putDouble("PointAZ", connection.pointA().z);
            entry.putDouble("PointBX", connection.pointB().x);
            entry.putDouble("PointBY", connection.pointB().y);
            entry.putDouble("PointBZ", connection.pointB().z);
            entry.putInt("Mode", connection.mode().ordinal());
            entry.putDouble("Sag", connection.sag());
            entry.putInt("Color", connection.color().getId());
            list.add(entry);
        }

        tag.put(CONNECTIONS, list);
    }

    @Override
    protected void loadAdditional(
            CompoundTag tag,
            HolderLookup.Provider registries
    ) {
        super.loadAdditional(tag, registries);
        connections.clear();

        if (tag.contains(CONNECTIONS, Tag.TAG_LIST)) {
            ListTag list = tag.getList(CONNECTIONS, Tag.TAG_COMPOUND);

            for (int index = 0; index < list.size(); index++) {
                connections.add(readConnection(list.getCompound(index)));
            }

            return;
        }

        // Old one-ended strings still load. Newly placed strings use both anchors.
        if (tag.contains("PointAX") && tag.contains("PointBX")) {
            Vec3 pointB = new Vec3(
                    tag.getDouble("PointBX"),
                    tag.getDouble("PointBY"),
                    tag.getDouble("PointBZ")
            );

            connections.add(new Connection(
                    UUID.randomUUID(),
                    worldPosition,
                    BlockPos.containing(pointB),
                    new Vec3(
                            tag.getDouble("PointAX"),
                            tag.getDouble("PointAY"),
                            tag.getDouble("PointAZ")
                    ),
                    pointB,
                    FairyLightsMode.byOrdinal(tag.getInt("Mode")),
                    tag.contains("Sag") ? tag.getDouble("Sag") : 0.22D,
                    tag.contains("Color")
                            ? DyeColor.byId(tag.getInt("Color"))
                            : DyeColor.WHITE
            ));
        }
    }

    private Connection readConnection(CompoundTag tag) {
        Vec3 pointA = new Vec3(
                tag.getDouble("PointAX"),
                tag.getDouble("PointAY"),
                tag.getDouble("PointAZ")
        );
        Vec3 pointB = new Vec3(
                tag.getDouble("PointBX"),
                tag.getDouble("PointBY"),
                tag.getDouble("PointBZ")
        );

        BlockPos anchorA = tag.contains("AnchorA")
                ? BlockPos.of(tag.getLong("AnchorA"))
                : worldPosition;
        BlockPos anchorB = tag.contains("AnchorB")
                ? BlockPos.of(tag.getLong("AnchorB"))
                : BlockPos.containing(pointB);

        return new Connection(
                tag.hasUUID("Id") ? tag.getUUID("Id") : UUID.randomUUID(),
                anchorA,
                anchorB,
                pointA,
                pointB,
                FairyLightsMode.byOrdinal(tag.getInt("Mode")),
                tag.contains("Sag") ? tag.getDouble("Sag") : 0.22D,
                tag.contains("Color")
                        ? DyeColor.byId(tag.getInt("Color"))
                        : DyeColor.WHITE
        );
    }

    public AABB getRenderBoundingBox() {
        if (connections.isEmpty()) {
            return new AABB(worldPosition).inflate(0.5D);
        }

        double minX = worldPosition.getX();
        double minY = worldPosition.getY();
        double minZ = worldPosition.getZ();
        double maxX = worldPosition.getX() + 1.0D;
        double maxY = worldPosition.getY() + 1.0D;
        double maxZ = worldPosition.getZ() + 1.0D;

        for (Connection connection : connections) {
            double distance = connection.pointA().distanceTo(connection.pointB());
            double drop = distance * connection.sag();

            minX = Math.min(minX, Math.min(connection.pointA().x, connection.pointB().x));
            minY = Math.min(
                    minY,
                    Math.min(connection.pointA().y, connection.pointB().y) - drop
            );
            minZ = Math.min(minZ, Math.min(connection.pointA().z, connection.pointB().z));
            maxX = Math.max(maxX, Math.max(connection.pointA().x, connection.pointB().x));
            maxY = Math.max(maxY, Math.max(connection.pointA().y, connection.pointB().y));
            maxZ = Math.max(maxZ, Math.max(connection.pointA().z, connection.pointB().z));
        }

        return new AABB(minX, minY, minZ, maxX, maxY, maxZ).inflate(0.5D);
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

    public static final class Connection {
        private final UUID id;
        private final BlockPos anchorA;
        private final BlockPos anchorB;
        private final Vec3 pointA;
        private final Vec3 pointB;
        private FairyLightsMode mode;
        private double sag;
        private DyeColor color;

        public Connection(
                UUID id,
                BlockPos anchorA,
                BlockPos anchorB,
                Vec3 pointA,
                Vec3 pointB,
                FairyLightsMode mode,
                double sag,
                DyeColor color
        ) {
            this.id = id;
            this.anchorA = anchorA.immutable();
            this.anchorB = anchorB.immutable();
            this.pointA = pointA;
            this.pointB = pointB;
            this.mode = mode;
            this.sag = sag;
            this.color = color;
        }

        public UUID id() {
            return id;
        }

        public BlockPos anchorA() {
            return anchorA;
        }

        public BlockPos anchorB() {
            return anchorB;
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

        public DyeColor color() {
            return color;
        }

        private void setMode(FairyLightsMode mode) {
            this.mode = mode;
        }

        private void setSag(double sag) {
            this.sag = sag;
        }

        private void setColor(DyeColor color) {
            this.color = color;
        }

        private void adjustSag(double amount) {
            sag += amount;

            if (sag < 0.04D) {
                sag = 0.32D;
            } else if (sag > 0.32D) {
                sag = 0.04D;
            }
        }

        private Connection copy() {
            return new Connection(
                    id,
                    anchorA,
                    anchorB,
                    pointA,
                    pointB,
                    mode,
                    sag,
                    color
            );
        }
    }
}