$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$src = Join-Path $root "src\main\java\net\droingo\decor"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backup = Join-Path $root "_fairy_grid_backup_$timestamp"
$utf8 = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path $src)) {
    throw "Run this from the Droingos-Decor project root."
}

$targets = @(
    "content\FairyLightsItem.java",
    "content\FairyLightsTestBlock.java",
    "content\FairyLightsTestBlockEntity.java",
    "client\render\FairyLightsPlacementPreview.java",
    "client\render\FairyLightsTestRenderer.java"
)

foreach ($relative in $targets) {
    $source = Join-Path $src $relative
    if (Test-Path $source) {
        $destination = Join-Path $backup $relative
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        Copy-Item $source $destination -Force
    }
}

function Write-Utf8 {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )
    New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

$item = @'
package net.droingo.decor.content;

import net.droingo.decor.registry.DecorBlocks;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.chat.Component;
import net.minecraft.util.Mth;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.DyeColor;
import net.minecraft.world.item.DyeItem;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.context.UseOnContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;

public final class FairyLightsItem extends Item {
    public static final String ROOT = "DroingosDecorFairyLights";
    public static final String HAS_FIRST = "HasFirst";
    public static final String DIMENSION = "Dimension";
    public static final String ANCHOR_POS = "AnchorPos";
    public static final String POINT_X = "PointX";
    public static final String POINT_Y = "PointY";
    public static final String POINT_Z = "PointZ";

    private static final double MAX_DISTANCE = 16.0D;
    private static final double SURFACE_OFFSET = 1.0D / 64.0D;

    public FairyLightsItem(Properties properties) {
        super(properties);
    }

    @Override
    public InteractionResult useOn(UseOnContext context) {
        Player player = context.getPlayer();
        if (player == null) {
            return InteractionResult.PASS;
        }

        Level level = context.getLevel();
        CompoundTag root = player.getPersistentData();
        CompoundTag data = root.getCompound(ROOT);

        Vec3 clickedPoint = snapToGrid(
                context.getClickedPos(),
                context.getClickedFace(),
                context.getClickLocation()
        );

        if (!data.getBoolean(HAS_FIRST)) {
            BlockPos anchorBlockPos = placementBlockPos(
                    context.getClickedPos(),
                    context.getClickedFace()
            );

            data.putBoolean(HAS_FIRST, true);
            data.putString(
                    DIMENSION,
                    level.dimension().location().toString()
            );
            data.putLong(ANCHOR_POS, anchorBlockPos.asLong());
            data.putDouble(POINT_X, clickedPoint.x);
            data.putDouble(POINT_Y, clickedPoint.y);
            data.putDouble(POINT_Z, clickedPoint.z);
            root.put(ROOT, data);

            if (!level.isClientSide) {
                player.displayClientMessage(
                        Component.literal(
                                "Fairy lights: first grid point selected. "
                                        + "Right-click the second point."
                        ),
                        true
                );
            }

            return InteractionResult.sidedSuccess(level.isClientSide);
        }

        if (!data.getString(DIMENSION).equals(
                level.dimension().location().toString()
        )) {
            clear(player);
            if (!level.isClientSide) {
                player.displayClientMessage(
                        Component.literal(
                                "Fairy lights selection cleared: "
                                        + "both points must be in the same dimension."
                        ),
                        true
                );
            }
            return InteractionResult.FAIL;
        }

        Vec3 firstPoint = firstPoint(data);
        double distance = firstPoint.distanceTo(clickedPoint);

        if (distance < 0.5D || distance > MAX_DISTANCE) {
            if (!level.isClientSide) {
                player.displayClientMessage(
                        Component.literal(
                                distance > MAX_DISTANCE
                                        ? "Fairy lights are limited to 16 blocks."
                                        : "The two points are too close together."
                        ),
                        true
                );
            }
            return InteractionResult.FAIL;
        }

        BlockPos anchorPos = BlockPos.of(data.getLong(ANCHOR_POS));
        boolean existingAnchor =
                level.getBlockState(anchorPos).is(DecorBlocks.FAIRY_LIGHTS_TEST);

        if (!existingAnchor
                && !level.getBlockState(anchorPos).canBeReplaced()) {
            clear(player);
            if (!level.isClientSide) {
                player.displayClientMessage(
                        Component.literal(
                                "The first attachment point is now obstructed."
                        ),
                        true
                );
            }
            return InteractionResult.FAIL;
        }

        if (!level.isClientSide) {
            if (!existingAnchor) {
                level.setBlock(
                        anchorPos,
                        DecorBlocks.FAIRY_LIGHTS_TEST
                                .get()
                                .defaultBlockState(),
                        3
                );
            }

            if (level.getBlockEntity(anchorPos)
                    instanceof FairyLightsTestBlockEntity lights) {
                lights.addConnection(
                        firstPoint,
                        clickedPoint,
                        context.isSecondaryUseActive(),
                        colorFromStack(context.getItemInHand())
                );
            }

            if (!player.getAbilities().instabuild) {
                context.getItemInHand().shrink(1);
            }

            player.displayClientMessage(
                    Component.literal(
                            existingAnchor
                                    ? "Another fairy-light string was added "
                                            + "to this grid point."
                                    : "Fairy lights placed."
                    ),
                    true
            );
        }

        clear(player);
        return InteractionResult.sidedSuccess(level.isClientSide);
    }

    public static boolean hasFirstPoint(Player player) {
        return player.getPersistentData()
                .getCompound(ROOT)
                .getBoolean(HAS_FIRST);
    }

    public static Vec3 selectedPoint(Player player) {
        return firstPoint(
                player.getPersistentData().getCompound(ROOT)
        );
    }

    private static Vec3 firstPoint(CompoundTag data) {
        return new Vec3(
                data.getDouble(POINT_X),
                data.getDouble(POINT_Y),
                data.getDouble(POINT_Z)
        );
    }

    private static DyeColor colorFromStack(ItemStack stack) {
        return stack.getItem() instanceof DyeItem dye
                ? dye.getDyeColor()
                : DyeColor.WHITE;
    }

    private static BlockPos placementBlockPos(
            BlockPos clickedPos,
            Direction face
    ) {
        return clickedPos.relative(face);
    }

    public static Vec3 snapToGrid(
            BlockPos clickedPos,
            Direction face,
            Vec3 hit
    ) {
        double localX = Mth.clamp(
                hit.x - clickedPos.getX(),
                0.0D,
                0.999999D
        );
        double localY = Mth.clamp(
                hit.y - clickedPos.getY(),
                0.0D,
                0.999999D
        );
        double localZ = Mth.clamp(
                hit.z - clickedPos.getZ(),
                0.0D,
                0.999999D
        );

        double x = clickedPos.getX() + localX;
        double y = clickedPos.getY() + localY;
        double z = clickedPos.getZ() + localZ;

        switch (face.getAxis()) {
            case X -> {
                y = clickedPos.getY() + gridCentre(localY);
                z = clickedPos.getZ() + gridCentre(localZ);
                x = face == Direction.EAST
                        ? clickedPos.getX() + 1.0D + SURFACE_OFFSET
                        : clickedPos.getX() - SURFACE_OFFSET;
            }
            case Y -> {
                x = clickedPos.getX() + gridCentre(localX);
                z = clickedPos.getZ() + gridCentre(localZ);
                y = face == Direction.UP
                        ? clickedPos.getY() + 1.0D + SURFACE_OFFSET
                        : clickedPos.getY() - SURFACE_OFFSET;
            }
            case Z -> {
                x = clickedPos.getX() + gridCentre(localX);
                y = clickedPos.getY() + gridCentre(localY);
                z = face == Direction.SOUTH
                        ? clickedPos.getZ() + 1.0D + SURFACE_OFFSET
                        : clickedPos.getZ() - SURFACE_OFFSET;
            }
        }

        return new Vec3(x, y, z);
    }

    private static double gridCentre(double coordinate) {
        int index = Math.min(
                2,
                (int) Math.floor(coordinate * 3.0D)
        );
        return (index + 0.5D) / 3.0D;
    }

    private static void clear(Player player) {
        player.getPersistentData().remove(ROOT);
    }
}
'@

$blockEntity = @'
package net.droingo.decor.content;

import net.droingo.decor.registry.DecorBlockEntities;
import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.nbt.Tag;
import net.minecraft.network.protocol.game.ClientboundBlockEntityDataPacket;
import net.minecraft.world.item.DyeColor;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public final class FairyLightsTestBlockEntity extends BlockEntity {
    private static final String CONNECTIONS = "Connections";
    private static final double SLOT_MATCH_DISTANCE_SQUARED = 0.08D * 0.08D;

    private final List<Connection> connections = new ArrayList<>();

    public FairyLightsTestBlockEntity(BlockPos pos, BlockState state) {
        super(DecorBlockEntities.FAIRY_LIGHTS_TEST.get(), pos, state);
    }

    public void addConnection(
            Vec3 firstPoint,
            Vec3 secondPoint,
            boolean taut,
            DyeColor color
    ) {
        connections.add(new Connection(
                firstPoint,
                secondPoint,
                FairyLightsMode.STEADY,
                taut ? 0.08D : 0.22D,
                color
        ));
        sync();
    }

    public List<Connection> connections() {
        return Collections.unmodifiableList(connections);
    }

    public boolean configured() {
        return !connections.isEmpty();
    }

    public int countAt(Vec3 point) {
        int count = 0;
        Vec3 target = nearestMountPoint(point);

        if (target == null) {
            return 0;
        }

        for (Connection connection : connections) {
            if (sameMount(connection.pointA(), target)) {
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
            if (sameMount(connection.pointA(), target)) {
                connection.setMode(next);
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
            if (sameMount(connection.pointA(), target)) {
                connection.adjustSag(amount);
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
            if (sameMount(connection.pointA(), target)) {
                connection.setColor(color);
            }
        }
        sync();
    }

    public Vec3 nearestMountPoint(Vec3 point) {
        Connection connection = nearestConnection(point);
        return connection == null ? null : connection.pointA();
    }

    private Connection nearestConnection(Vec3 point) {
        Connection nearest = null;
        double bestDistance = Double.POSITIVE_INFINITY;

        for (Connection connection : connections) {
            double distance = connection.pointA().distanceToSqr(point);
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

        if (tag.contains("PointAX") && tag.contains("PointBX")) {
            connections.add(readConnection(tag));
        }
    }

    private static Connection readConnection(CompoundTag tag) {
        return new Connection(
                new Vec3(
                        tag.getDouble("PointAX"),
                        tag.getDouble("PointAY"),
                        tag.getDouble("PointAZ")
                ),
                new Vec3(
                        tag.getDouble("PointBX"),
                        tag.getDouble("PointBY"),
                        tag.getDouble("PointBZ")
                ),
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
        private final Vec3 pointA;
        private final Vec3 pointB;
        private FairyLightsMode mode;
        private double sag;
        private DyeColor color;

        private Connection(
                Vec3 pointA,
                Vec3 pointB,
                FairyLightsMode mode,
                double sag,
                DyeColor color
        ) {
            this.pointA = pointA;
            this.pointB = pointB;
            this.mode = mode;
            this.sag = sag;
            this.color = color;
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
    }
}
'@

$block = @'
package net.droingo.decor.content;

import com.mojang.serialization.MapCodec;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.ItemInteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.DyeItem;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.BaseEntityBlock;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.Vec3;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;
import org.jetbrains.annotations.Nullable;

public final class FairyLightsTestBlock extends BaseEntityBlock {
    public static final MapCodec<FairyLightsTestBlock> CODEC =
            simpleCodec(FairyLightsTestBlock::new);

    private static final double HALF_SIZE = 1.5D / 16.0D;

    public FairyLightsTestBlock(Properties properties) {
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
        return new FairyLightsTestBlockEntity(pos, state);
    }

    @Override
    protected ItemInteractionResult useItemOn(
            ItemStack stack,
            BlockState state,
            Level level,
            BlockPos pos,
            Player player,
            InteractionHand hand,
            BlockHitResult hit
    ) {
        if (!(stack.getItem() instanceof DyeItem dyeItem)) {
            return ItemInteractionResult.PASS_TO_DEFAULT_BLOCK_INTERACTION;
        }

        if (!(level.getBlockEntity(pos)
                instanceof FairyLightsTestBlockEntity lights)) {
            return ItemInteractionResult.PASS_TO_DEFAULT_BLOCK_INTERACTION;
        }

        Vec3 target = lights.nearestMountPoint(hit.getLocation());
        if (target == null) {
            return ItemInteractionResult.PASS_TO_DEFAULT_BLOCK_INTERACTION;
        }

        if (!level.isClientSide) {
            lights.dyeAt(target, dyeItem.getDyeColor());

            if (!player.getAbilities().instabuild) {
                stack.shrink(1);
            }

            player.displayClientMessage(
                    Component.literal(
                            "Fairy-light point dyed "
                                    + dyeItem.getDyeColor().getName()
                                    + "."
                    ),
                    true
            );
        }

        return ItemInteractionResult.sidedSuccess(level.isClientSide);
    }

    @Override
    protected InteractionResult useWithoutItem(
            BlockState state,
            Level level,
            BlockPos pos,
            Player player,
            BlockHitResult hit
    ) {
        if (!(level.getBlockEntity(pos)
                instanceof FairyLightsTestBlockEntity lights)) {
            return InteractionResult.PASS;
        }

        Vec3 target = lights.nearestMountPoint(hit.getLocation());
        if (target == null) {
            return InteractionResult.PASS;
        }

        if (!level.isClientSide) {
            if (player.isShiftKeyDown()) {
                lights.adjustSagAt(target, -0.08D);
            } else {
                lights.cycleModeAt(target);
            }

            player.displayClientMessage(
                    Component.literal(
                            "Fairy lights: "
                                    + lights.modeAt(target).displayName()
                                    + " | Sag "
                                    + Math.round(lights.sagAt(target) * 100.0D)
                                    + "% | Strings here "
                                    + lights.countAt(target)
                    ),
                    true
            );
        }

        return InteractionResult.sidedSuccess(level.isClientSide);
    }

    @Override
    protected VoxelShape getShape(
            BlockState state,
            BlockGetter level,
            BlockPos pos,
            CollisionContext context
    ) {
        if (!(level.getBlockEntity(pos)
                instanceof FairyLightsTestBlockEntity lights)) {
            return Shapes.empty();
        }

        VoxelShape shape = Shapes.empty();

        for (FairyLightsTestBlockEntity.Connection connection
                : lights.connections()) {
            Vec3 local = connection.pointA().subtract(
                    pos.getX(),
                    pos.getY(),
                    pos.getZ()
            );

            shape = Shapes.or(
                    shape,
                    Shapes.box(
                            clamp(local.x - HALF_SIZE),
                            clamp(local.y - HALF_SIZE),
                            clamp(local.z - HALF_SIZE),
                            clamp(local.x + HALF_SIZE),
                            clamp(local.y + HALF_SIZE),
                            clamp(local.z + HALF_SIZE)
                    )
            );
        }

        return shape.optimize();
    }

    @Override
    protected VoxelShape getCollisionShape(
            BlockState state,
            BlockGetter level,
            BlockPos pos,
            CollisionContext context
    ) {
        return Shapes.empty();
    }

    private static double clamp(double value) {
        return Math.max(0.0D, Math.min(1.0D, value));
    }
}
'@

$preview = @'
package net.droingo.decor.client.render;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.content.FairyLightsItem;
import net.droingo.decor.registry.DecorItems;
import net.minecraft.client.Minecraft;
import net.minecraft.core.particles.DustParticleOptions;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.Vec3;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.client.event.ClientTickEvent;
import org.joml.Vector3f;

@EventBusSubscriber(
        modid = DroingosDecor.MOD_ID,
        value = Dist.CLIENT
)
public final class FairyLightsPlacementPreview {
    private static final DustParticleOptions PREVIEW_PARTICLE =
            new DustParticleOptions(
                    new Vector3f(1.0F, 0.85F, 0.35F),
                    0.45F
            );

    private FairyLightsPlacementPreview() {
    }

    @SubscribeEvent
    public static void clientTick(ClientTickEvent.Post event) {
        Minecraft minecraft = Minecraft.getInstance();

        if (minecraft.level == null
                || minecraft.player == null
                || minecraft.isPaused()
                || !minecraft.player.getMainHandItem()
                        .is(DecorItems.FAIRY_LIGHTS.get())
                || !FairyLightsItem.hasFirstPoint(minecraft.player)
                || !(minecraft.hitResult instanceof BlockHitResult hit)) {
            return;
        }

        Vec3 start = FairyLightsItem.selectedPoint(minecraft.player);
        Vec3 end = FairyLightsItem.snapToGrid(
                hit.getBlockPos(),
                hit.getDirection(),
                hit.getLocation()
        );

        double distance = start.distanceTo(end);
        if (distance < 0.05D || distance > 16.0D) {
            return;
        }

        int particles = Math.max(8, (int) Math.ceil(distance * 8.0D));
        for (int index = 0; index <= particles; index++) {
            double t = index / (double) particles;
            Vec3 point = FairyLightsTestRenderer.curve(
                    start,
                    end,
                    t,
                    minecraft.player.isShiftKeyDown() ? 0.08D : 0.22D
            );

            minecraft.level.addParticle(
                    PREVIEW_PARTICLE,
                    point.x,
                    point.y,
                    point.z,
                    0.0D,
                    0.0D,
                    0.0D
            );
        }
    }
}
'@

Write-Utf8 (Join-Path $src "content\FairyLightsItem.java") $item
Write-Utf8 (Join-Path $src "content\FairyLightsTestBlockEntity.java") $blockEntity
Write-Utf8 (Join-Path $src "content\FairyLightsTestBlock.java") $block
Write-Utf8 (Join-Path $src "client\render\FairyLightsPlacementPreview.java") $preview

$rendererPath = Join-Path $src "client\render\FairyLightsTestRenderer.java"
$rendererText = [System.IO.File]::ReadAllText($rendererPath)

if ($rendererText -notmatch 'BULB_SPACING\s*=\s*0\.5D') {
    throw "Could not find the existing BULB_SPACING = 0.5D value."
}

$rendererText = $rendererText -replace `
    'private static final double BULB_SPACING = 0\.5D;', `
    'private static final double BULB_SPACING = 0.4D;'

[System.IO.File]::WriteAllText(
    $rendererPath,
    $rendererText,
    $utf8
)

Write-Host ""
Write-Host "Fairy-light 3x3 grid update installed." -ForegroundColor Green
Write-Host "Backup: $backup" -ForegroundColor Cyan
Write-Host ""
Write-Host "Changes:" -ForegroundColor Yellow
Write-Host "- Both endpoints snap to a 3x3 grid on any block face"
Write-Host "- Each occupied mounting point has its own small hitbox"
Write-Host "- Dye, mode and sag interactions target only that grid point"
Write-Host "- Multiple strings can still share one grid point"
Write-Host "- Bulb spacing reduced from 0.5 to 0.4 blocks"
Write-Host "  (roughly 25 percent more bulbs)"
Write-Host ""
Write-Host "Now run: .\gradlew.bat compileJava" -ForegroundColor Yellow
