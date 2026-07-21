$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
$src = Join-Path $root "src\main\java\net\droingo\decor"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backup = Join-Path $root "_fairy_lights_backup_$timestamp"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path $src)) {
    throw "Run this from the Droingos-Decor project root."
}

$files = @(
    "content\FairyLightsTestBlockEntity.java",
    "content\FairyLightsTestBlock.java",
    "content\FairyLightsItem.java",
    "client\render\FairyLightsTestRenderer.java",
    "client\render\FairyLightsPlacementPreview.java",
    "registry\DecorBlocks.java"
)

foreach ($relative in $files) {
    $source = Join-Path $src $relative
    if (Test-Path $source) {
        $destination = Join-Path $backup $relative
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        Copy-Item $source $destination -Force
    }
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

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

    public void cycleMode() {
        if (connections.isEmpty()) {
            return;
        }

        FairyLightsMode next = connections.get(0).mode().next();
        for (Connection connection : connections) {
            connection.setMode(next);
        }
        sync();
    }

    public FairyLightsMode mode() {
        return connections.isEmpty()
                ? FairyLightsMode.STEADY
                : connections.get(0).mode();
    }

    public void adjustSag(double amount) {
        for (Connection connection : connections) {
            connection.adjustSag(amount);
        }
        sync();
    }

    public double sag() {
        return connections.isEmpty() ? 0.22D : connections.get(0).sag();
    }

    public void dyeAll(DyeColor color) {
        for (Connection connection : connections) {
            connection.setColor(color);
        }
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
                CompoundTag entry = list.getCompound(index);
                connections.add(readConnection(entry));
            }
            return;
        }

        // Backwards compatibility with the original one-string test format.
        if (tag.contains("PointAX") && tag.contains("PointBX")) {
            connections.add(readConnection(tag));
        }
    }

    private static Connection readConnection(CompoundTag tag) {
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

        return new Connection(
                pointA,
                pointB,
                FairyLightsMode.byOrdinal(tag.getInt("Mode")),
                tag.contains("Sag") ? tag.getDouble("Sag") : 0.22D,
                tag.contains("Color")
                        ? DyeColor.byId(tag.getInt("Color"))
                        : DyeColor.WHITE
        );
    }

    @Override
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
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;
import org.jetbrains.annotations.Nullable;

public final class FairyLightsTestBlock extends BaseEntityBlock {
    public static final MapCodec<FairyLightsTestBlock> CODEC =
            simpleCodec(FairyLightsTestBlock::new);

    private static final VoxelShape SHAPE = Shapes.box(
            6.0D / 16.0D,
            6.0D / 16.0D,
            6.0D / 16.0D,
            10.0D / 16.0D,
            10.0D / 16.0D,
            10.0D / 16.0D
    );

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

        if (!level.isClientSide) {
            lights.dyeAll(dyeItem.getDyeColor());

            if (!player.getAbilities().instabuild) {
                stack.shrink(1);
            }

            player.displayClientMessage(
                    Component.literal(
                            "Fairy lights dyed "
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

        if (!level.isClientSide) {
            if (player.isShiftKeyDown()) {
                lights.adjustSag(-0.08D);
            } else {
                lights.cycleMode();
            }

            player.displayClientMessage(
                    Component.literal(
                            "Fairy lights: "
                                    + lights.mode().displayName()
                                    + " | Sag "
                                    + Math.round(lights.sag() * 100.0D)
                                    + "% | Strings "
                                    + lights.connections().size()
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
        return SHAPE;
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
}
'@

$item = @'
package net.droingo.decor.content;

import net.droingo.decor.registry.DecorBlocks;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.chat.Component;
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

        Vec3 clickedPoint = offsetFromSurface(
                context.getClickLocation(),
                context.getClickedFace()
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
                                "Fairy lights: first point selected. "
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
                                            + "to this mounting point."
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

    public static Vec3 offsetFromSurface(
            Vec3 hit,
            Direction face
    ) {
        Vec3 normal = Vec3.atLowerCornerOf(face.getNormal());
        return hit.add(normal.scale(0.015625D));
    }

    private static void clear(Player player) {
        player.getPersistentData().remove(ROOT);
    }
}
'@

$renderer = @'
package net.droingo.decor.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import net.droingo.decor.DroingosDecor;
import net.droingo.decor.content.FairyLightsMode;
import net.droingo.decor.content.FairyLightsTestBlockEntity;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.block.BlockRenderDispatcher;
import net.minecraft.client.renderer.blockentity.BlockEntityRenderer;
import net.minecraft.client.renderer.blockentity.BlockEntityRendererProvider;
import net.minecraft.client.resources.model.BakedModel;
import net.minecraft.client.resources.model.ModelResourceLocation;
import net.minecraft.core.BlockPos;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.item.DyeColor;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.phys.Vec3;
import net.neoforged.neoforge.client.model.data.ModelData;
import org.joml.Quaternionf;

public final class FairyLightsTestRenderer
        implements BlockEntityRenderer<FairyLightsTestBlockEntity> {

    private static final ResourceLocation WIRE_MODEL =
            id("block/fairy_lights_wire");
    private static final ResourceLocation BULB_MODEL =
            id("block/fairy_lights_bulb");
    private static final ResourceLocation GLOW_MODEL =
            id("block/fairy_lights_glow");

    private static final int FULL_BRIGHT = 0x00F000F0;
    private static final double BULB_SPACING = 0.5D;

    private final BlockRenderDispatcher blockRenderer;

    public FairyLightsTestRenderer(
            BlockEntityRendererProvider.Context context
    ) {
        blockRenderer = context.getBlockRenderDispatcher();
    }

    @Override
    public void render(
            FairyLightsTestBlockEntity blockEntity,
            float partialTick,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        BlockPos origin = blockEntity.getBlockPos();

        for (FairyLightsTestBlockEntity.Connection connection
                : blockEntity.connections()) {
            Vec3 start = connection.pointA().subtract(
                    origin.getX(),
                    origin.getY(),
                    origin.getZ()
            );
            Vec3 end = connection.pointB().subtract(
                    origin.getX(),
                    origin.getY(),
                    origin.getZ()
            );

            renderConnection(
                    blockEntity,
                    connection,
                    start,
                    end,
                    partialTick,
                    poseStack,
                    buffers,
                    packedLight,
                    packedOverlay
            );
        }
    }

    private void renderConnection(
            FairyLightsTestBlockEntity blockEntity,
            FairyLightsTestBlockEntity.Connection connection,
            Vec3 start,
            Vec3 end,
            float partialTick,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        double directDistance = start.distanceTo(end);
        int wireSegments = Math.max(
                8,
                Math.min(128, (int) Math.ceil(directDistance * 8.0D))
        );

        for (int index = 0; index < wireSegments; index++) {
            double t0 = index / (double) wireSegments;
            double t1 = (index + 1) / (double) wireSegments;
            Vec3 p0 = curve(start, end, t0, connection.sag());
            Vec3 p1 = curve(start, end, t1, connection.sag());
            renderWireSegment(
                    p0,
                    p1,
                    poseStack,
                    buffers,
                    packedLight,
                    packedOverlay
            );
        }

        int bulbCount = Math.max(
                2,
                (int) Math.floor(directDistance / BULB_SPACING) + 1
        );

        long gameTime = blockEntity.getLevel() == null
                ? 0L
                : blockEntity.getLevel().getGameTime();

        float[] color = rgb(connection.color());

        for (int index = 0; index < bulbCount; index++) {
            double t = bulbCount == 1
                    ? 0.5D
                    : index / (double) (bulbCount - 1);

            Vec3 position = curve(
                    start,
                    end,
                    t,
                    connection.sag()
            );

            renderBulb(
                    position,
                    false,
                    color,
                    poseStack,
                    buffers,
                    packedLight,
                    packedOverlay
            );

            if (isLit(
                    connection.mode(),
                    index,
                    bulbCount,
                    gameTime,
                    partialTick
            )) {
                renderBulb(
                        position,
                        true,
                        color,
                        poseStack,
                        buffers,
                        FULL_BRIGHT,
                        packedOverlay
                );
            }
        }
    }

    private void renderWireSegment(
            Vec3 start,
            Vec3 end,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        Vec3 delta = end.subtract(start);
        double length = delta.length();
        if (length < 0.0001D) {
            return;
        }

        Vec3 direction = delta.scale(1.0D / length);

        poseStack.pushPose();
        poseStack.translate(start.x, start.y, start.z);
        poseStack.mulPose(
                new Quaternionf().rotationTo(
                        0.0F,
                        0.0F,
                        1.0F,
                        (float) direction.x,
                        (float) direction.y,
                        (float) direction.z
                )
        );
        poseStack.scale(1.0F, 1.0F, (float) length);
        poseStack.translate(-0.5D, -7.25D / 16.0D, 0.0D);

        renderModel(
                WIRE_MODEL,
                poseStack,
                buffers,
                1.0F,
                1.0F,
                1.0F,
                packedLight,
                packedOverlay
        );
        poseStack.popPose();
    }

    private void renderBulb(
            Vec3 position,
            boolean glow,
            float[] color,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        poseStack.pushPose();
        poseStack.translate(position.x, position.y, position.z);
        poseStack.translate(-0.5D, -7.0D / 16.0D, -0.5D);

        renderModel(
                glow ? GLOW_MODEL : BULB_MODEL,
                poseStack,
                buffers,
                color[0],
                color[1],
                color[2],
                packedLight,
                packedOverlay
        );
        poseStack.popPose();
    }

    private void renderModel(
            ResourceLocation location,
            PoseStack poseStack,
            MultiBufferSource buffers,
            float red,
            float green,
            float blue,
            int packedLight,
            int packedOverlay
    ) {
        BakedModel model = Minecraft.getInstance()
                .getModelManager()
                .getModel(ModelResourceLocation.standalone(location));

        RenderType renderType = RenderType.cutout();
        VertexConsumer consumer = buffers.getBuffer(renderType);

        blockRenderer.getModelRenderer().renderModel(
                poseStack.last(),
                consumer,
                Blocks.AIR.defaultBlockState(),
                model,
                red,
                green,
                blue,
                packedLight,
                packedOverlay,
                ModelData.EMPTY,
                renderType
        );
    }

    public static Vec3 curve(
            Vec3 start,
            Vec3 end,
            double t,
            double sagFactor
    ) {
        Vec3 linear = start.lerp(end, t);
        double distance = start.distanceTo(end);
        double sag = distance
                * sagFactor
                * 4.0D
                * t
                * (1.0D - t);

        return linear.add(0.0D, -sag, 0.0D);
    }

    private static boolean isLit(
            FairyLightsMode mode,
            int index,
            int count,
            long gameTime,
            float partialTick
    ) {
        long tick = gameTime;
        return switch (mode) {
            case STEADY -> true;
            case OFF -> false;
            case ALTERNATING ->
                    ((index & 1) == ((tick / 10L) & 1L));
            case CHASE -> {
                int active = (int) ((tick / 3L) % Math.max(1, count));
                int distance = Math.floorMod(index - active, Math.max(1, count));
                yield distance <= 2;
            }
            case TWINKLE -> {
                long seed = index * 341873128712L;
                long phase = Math.floorMod(seed, 37L);
                yield Math.floorMod(tick + phase, 37L) < 18L;
            }
            case PULSE ->
                    Math.floorMod(tick, 40L) < 24L;
        };
    }

    private static float[] rgb(DyeColor color) {
        return switch (color) {
            case WHITE -> new float[]{1.00F, 1.00F, 1.00F};
            case ORANGE -> new float[]{1.00F, 0.50F, 0.12F};
            case MAGENTA -> new float[]{0.78F, 0.25F, 0.78F};
            case LIGHT_BLUE -> new float[]{0.35F, 0.70F, 1.00F};
            case YELLOW -> new float[]{1.00F, 0.88F, 0.20F};
            case LIME -> new float[]{0.50F, 0.90F, 0.18F};
            case PINK -> new float[]{1.00F, 0.45F, 0.67F};
            case GRAY -> new float[]{0.35F, 0.35F, 0.35F};
            case LIGHT_GRAY -> new float[]{0.68F, 0.68F, 0.68F};
            case CYAN -> new float[]{0.15F, 0.65F, 0.70F};
            case PURPLE -> new float[]{0.50F, 0.20F, 0.70F};
            case BLUE -> new float[]{0.18F, 0.28F, 0.80F};
            case BROWN -> new float[]{0.45F, 0.28F, 0.15F};
            case GREEN -> new float[]{0.20F, 0.55F, 0.18F};
            case RED -> new float[]{0.85F, 0.16F, 0.14F};
            case BLACK -> new float[]{0.12F, 0.12F, 0.12F};
        };
    }

    @Override
    public boolean shouldRenderOffScreen(
            FairyLightsTestBlockEntity blockEntity
    ) {
        return true;
    }

    @Override
    public int getViewDistance() {
        return 128;
    }

    private static ResourceLocation id(String path) {
        return ResourceLocation.fromNamespaceAndPath(
                DroingosDecor.MOD_ID,
                path
        );
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
        Vec3 end = FairyLightsItem.offsetFromSurface(
                hit.getLocation(),
                hit.getDirection()
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

Write-Utf8NoBom (Join-Path $src "content\FairyLightsTestBlockEntity.java") $blockEntity
Write-Utf8NoBom (Join-Path $src "content\FairyLightsTestBlock.java") $block
Write-Utf8NoBom (Join-Path $src "content\FairyLightsItem.java") $item
Write-Utf8NoBom (Join-Path $src "client\render\FairyLightsTestRenderer.java") $renderer
Write-Utf8NoBom (Join-Path $src "client\render\FairyLightsPlacementPreview.java") $preview

$blocksPath = Join-Path $src "registry\DecorBlocks.java"
$blocksText = [System.IO.File]::ReadAllText($blocksPath)

$old = @'
                            .sound(SoundType.WOOD)
                            .noOcclusion()
                            .noCollission()
            );
'@

$new = @'
                            .sound(SoundType.WOOD)
                            .lightLevel(state -> 4)
                            .noOcclusion()
                            .noCollission()
            );
'@

$fairyStart = $blocksText.IndexOf(
    "public static final DeferredBlock<FairyLightsTestBlock> FAIRY_LIGHTS_TEST"
)

if ($fairyStart -lt 0) {
    throw "Could not find FAIRY_LIGHTS_TEST in DecorBlocks.java."
}

$afterFairy = $blocksText.Substring($fairyStart)
$relativeMatch = $afterFairy.IndexOf($old)

if ($relativeMatch -lt 0) {
    throw "Could not locate the fairy-light block properties."
}

$absoluteMatch = $fairyStart + $relativeMatch
$blocksText =
    $blocksText.Substring(0, $absoluteMatch) +
    $new +
    $blocksText.Substring($absoluteMatch + $old.Length)

[System.IO.File]::WriteAllText(
    $blocksPath,
    $blocksText,
    $utf8NoBom
)

Write-Host ""
Write-Host "Fairy-light upgrade installed." -ForegroundColor Green
Write-Host "Backup: $backup" -ForegroundColor Cyan
Write-Host ""
Write-Host "Included:" -ForegroundColor Yellow
Write-Host "- Small 4x4x4 anchor selection box"
Write-Host "- Live dotted sagging placement preview"
Write-Host "- Multiple strings from one anchor"
Write-Host "- Dye an anchor to recolour all attached strings"
Write-Host "- Low block light level of 4"
Write-Host "- Expanded render bounds and 128-block renderer distance"
Write-Host "- Backwards loading for existing single-string test lights"
Write-Host ""
Write-Host "Now run: .\gradlew.bat compileJava" -ForegroundColor Yellow
