param(
    [string]$ProjectRoot = "C:\Users\mmcdo\Desktop\Droingos-Decor"
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectRoot

Write-Host "Installing two-point fairy lights..."

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $full = Join-Path $ProjectRoot $Path
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $full) | Out-Null
    [System.IO.File]::WriteAllText(
        $full,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Replace-Required {
    param([string]$Path, [string]$Old, [string]$New)
    $full = Join-Path $ProjectRoot $Path
    $text = [System.IO.File]::ReadAllText($full)
    if (-not $text.Contains($Old)) {
        throw "Could not find expected text in $Path"
    }
    $text = $text.Replace($Old, $New)
    [System.IO.File]::WriteAllText(
        $full,
        $text,
        [System.Text.UTF8Encoding]::new($false)
    )
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backup = Join-Path $ProjectRoot "fairy_lights_catenary_backup_$stamp"
New-Item -ItemType Directory -Force -Path $backup | Out-Null

$backupTargets = @(
    "src\main\java\net\droingo\decor\content\FairyLightsTestBlock.java",
    "src\main\java\net\droingo\decor\content\FairyLightsTestBlockEntity.java",
    "src\main\java\net\droingo\decor\client\render\FairyLightsTestRenderer.java",
    "src\main\java\net\droingo\decor\registry\DecorItems.java",
    "src\main\java\net\droingo\decor\client\DroingosDecorClient.java"
)

foreach ($relative in $backupTargets) {
    $source = Join-Path $ProjectRoot $relative
    if (Test-Path $source) {
        $dest = Join-Path $backup $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Copy-Item $source $dest -Force
    }
}

Write-Utf8NoBom -Path "src/main/java/net/droingo/decor/content/FairyLightsItem.java" -Content @'
package net.droingo.decor.content;

import net.droingo.decor.registry.DecorBlocks;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.context.UseOnContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;

public final class FairyLightsItem extends Item {
    private static final String ROOT = "DroingosDecorFairyLights";
    private static final String HAS_FIRST = "HasFirst";
    private static final String DIMENSION = "Dimension";
    private static final String ANCHOR_POS = "AnchorPos";
    private static final String POINT_X = "PointX";
    private static final String POINT_Y = "PointY";
    private static final String POINT_Z = "PointZ";
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
            if (!level.isClientSide) {
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
            if (!level.isClientSide) {
                clear(player);
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

        Vec3 firstPoint = new Vec3(
                data.getDouble(POINT_X),
                data.getDouble(POINT_Y),
                data.getDouble(POINT_Z)
        );

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

        if (!level.getBlockState(anchorPos).canBeReplaced()) {
            if (!level.isClientSide) {
                clear(player);
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
            level.setBlock(
                    anchorPos,
                    DecorBlocks.FAIRY_LIGHTS_TEST
                            .get()
                            .defaultBlockState(),
                    3
            );

            if (level.getBlockEntity(anchorPos)
                    instanceof FairyLightsTestBlockEntity lights) {
                lights.configure(
                        firstPoint,
                        clickedPoint,
                        context.isSecondaryUseActive()
                );
            }

            if (!player.getAbilities().instabuild) {
                context.getItemInHand().shrink(1);
            }

            clear(player);
            player.displayClientMessage(
                    Component.literal(
                            "Fairy lights placed. Right-click the wire anchor "
                                    + "to change flashing mode."
                    ),
                    true
            );
        }

        return InteractionResult.sidedSuccess(level.isClientSide);
    }

    private static BlockPos placementBlockPos(
            BlockPos clickedPos,
            Direction face
    ) {
        return clickedPos.relative(face);
    }

    private static Vec3 offsetFromSurface(
            Vec3 hit,
            Direction face
    ) {
        Vec3 normal = Vec3.atLowerCornerOf(face.getNormal());
        return hit.add(normal.scale(0.015625D));
    }

    private static void clear(Player player) {
        CompoundTag root = player.getPersistentData();
        root.remove(ROOT);
    }
}
'@

Write-Utf8NoBom -Path "src/main/java/net/droingo/decor/content/FairyLightsTestBlock.java" -Content @'
package net.droingo.decor.content;

import com.mojang.serialization.MapCodec;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
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
            0.0D, 0.0D, 0.0D,
            1.0D, 1.0D, 1.0D
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
                                    + "%"
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

Write-Utf8NoBom -Path "src/main/java/net/droingo/decor/content/FairyLightsMode.java" -Content @'
package net.droingo.decor.content;

public enum FairyLightsMode {
    STEADY("Steady"),
    ALTERNATING("Alternating"),
    CHASE("Chase"),
    TWINKLE("Twinkle"),
    PULSE("Pulse"),
    OFF("Off");

    private final String displayName;

    FairyLightsMode(String displayName) {
        this.displayName = displayName;
    }

    public String displayName() {
        return displayName;
    }

    public FairyLightsMode next() {
        FairyLightsMode[] values = values();
        return values[(ordinal() + 1) % values.length];
    }

    public static FairyLightsMode byOrdinal(int ordinal) {
        FairyLightsMode[] values = values();
        if (ordinal < 0 || ordinal >= values.length) {
            return STEADY;
        }
        return values[ordinal];
    }
}
'@

Write-Utf8NoBom -Path "src/main/java/net/droingo/decor/content/FairyLightsTestBlockEntity.java" -Content @'
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

    @Override
    public AABB getRenderBoundingBox() {
        if (!configured()) {
            return super.getRenderBoundingBox();
        }

        double extra = Math.max(1.0D, pointA.distanceTo(pointB) * sag + 1.0D);

        return new AABB(
                Math.min(pointA.x, pointB.x),
                Math.min(pointA.y, pointB.y) - extra,
                Math.min(pointA.z, pointB.z),
                Math.max(pointA.x, pointB.x),
                Math.max(pointA.y, pointB.y) + 0.5D,
                Math.max(pointA.z, pointB.z)
        ).inflate(0.75D);
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
'@

Write-Utf8NoBom -Path "src/main/java/net/droingo/decor/client/render/FairyLightsTestRenderer.java" -Content @'
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
        if (!blockEntity.configured()) {
            return;
        }

        BlockPos origin = blockEntity.getBlockPos();
        Vec3 start = blockEntity.pointA().subtract(
                origin.getX(),
                origin.getY(),
                origin.getZ()
        );
        Vec3 end = blockEntity.pointB().subtract(
                origin.getX(),
                origin.getY(),
                origin.getZ()
        );

        double directDistance = start.distanceTo(end);
        int wireSegments = Math.max(
                8,
                Math.min(128, (int) Math.ceil(directDistance * 8.0D))
        );

        for (int index = 0; index < wireSegments; index++) {
            double t0 = index / (double) wireSegments;
            double t1 = (index + 1) / (double) wireSegments;
            Vec3 p0 = curve(start, end, t0, blockEntity.sag());
            Vec3 p1 = curve(start, end, t1, blockEntity.sag());
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

        for (int index = 0; index < bulbCount; index++) {
            double t = bulbCount == 1
                    ? 0.5D
                    : index / (double) (bulbCount - 1);

            Vec3 position = curve(
                    start,
                    end,
                    t,
                    blockEntity.sag()
            );

            renderBulb(
                    position,
                    false,
                    poseStack,
                    buffers,
                    packedLight,
                    packedOverlay
            );

            if (isLit(
                    blockEntity.mode(),
                    index,
                    bulbCount,
                    gameTime,
                    partialTick
            )) {
                renderBulb(
                        position,
                        true,
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
                packedLight,
                packedOverlay
        );
        poseStack.popPose();
    }

    private void renderBulb(
            Vec3 position,
            boolean glow,
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
                packedLight,
                packedOverlay
        );
        poseStack.popPose();
    }

    private void renderModel(
            ResourceLocation location,
            PoseStack poseStack,
            MultiBufferSource buffers,
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
                1.0F,
                1.0F,
                1.0F,
                packedLight,
                packedOverlay,
                ModelData.EMPTY,
                renderType
        );
    }

    private static Vec3 curve(
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

    @Override
    public boolean shouldRenderOffScreen(
            FairyLightsTestBlockEntity blockEntity
    ) {
        return true;
    }

    private static ResourceLocation id(String path) {
        return ResourceLocation.fromNamespaceAndPath(
                DroingosDecor.MOD_ID,
                path
        );
    }
}
'@

Write-Utf8NoBom -Path "src/main/resources/assets/droingos_decor/models/block/fairy_lights_wire.json" -Content @'
{
  "parent": "minecraft:block/block",
  "texture_size": [
    32,
    32
  ],
  "textures": {
    "0": "droingos_decor:block/fairy_lights",
    "particle": "droingos_decor:block/fairy_lights"
  },
  "elements": [
    {
      "from": [
        7.75,
        7,
        0
      ],
      "to": [
        8.25,
        7.5,
        16
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          8,
          7.25,
          15
        ]
      },
      "faces": {
        "north": {
          "uv": [
            2.5,
            1,
            2.75,
            1.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0,
            0,
            8,
            0.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            1.5,
            2.5,
            1.75,
            2.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            0.5,
            8,
            0.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0.25,
            9,
            0,
            1
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            0.75,
            1,
            0.5,
            9
          ],
          "texture": "#0"
        }
      }
    }
  ]
}
'@

Write-Utf8NoBom -Path "src/main/resources/assets/droingos_decor/models/block/fairy_lights_bulb.json" -Content @'
{
  "parent": "minecraft:block/block",
  "texture_size": [
    32,
    32
  ],
  "textures": {
    "0": "droingos_decor:block/fairy_lights",
    "particle": "droingos_decor:block/fairy_lights"
  },
  "elements": [
    {
      "from": [
        8,
        6.6,
        7.9
      ],
      "to": [
        8,
        7,
        8.2
      ],
      "rotation": {
        "angle": 45,
        "axis": "y",
        "origin": [
          8,
          7,
          8.05
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            0.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            2.5,
            1.5,
            2.75,
            1.75
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            0.25
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            2,
            2.5,
            2.25,
            2.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0,
            0.25,
            0,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            0,
            0,
            0,
            0.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        8,
        6.6,
        7.9
      ],
      "to": [
        8,
        7,
        8.2
      ],
      "rotation": {
        "angle": -45,
        "axis": "y",
        "origin": [
          8,
          7,
          8.05
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            0.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            2.5,
            2,
            2.75,
            2.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            0.25
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            2.5,
            2.5,
            2.75,
            2.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0,
            0.25,
            0,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            0,
            0,
            0,
            0.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        7.75,
        6.1,
        7.8
      ],
      "to": [
        8.25,
        6.6,
        8.3
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          8,
          7,
          8.05
        ]
      },
      "faces": {
        "north": {
          "uv": [
            1,
            3,
            1.25,
            3.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            3,
            1,
            3.25,
            1.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            1.5,
            3,
            1.75,
            3.25
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            3,
            1.5,
            3.25,
            1.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            2.25,
            3.25,
            2,
            3
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            3.25,
            2,
            3,
            2.25
          ],
          "texture": "#0"
        }
      }
    }
  ]
}
'@

Write-Utf8NoBom -Path "src/main/resources/assets/droingos_decor/models/block/fairy_lights_glow.json" -Content @'
{
  "parent": "minecraft:block/block",
  "texture_size": [
    32,
    32
  ],
  "textures": {
    "0": "droingos_decor:block/fairy_lights_emissive",
    "particle": "droingos_decor:block/fairy_lights"
  },
  "elements": [
    {
      "from": [
        7.65,
        6,
        7.7
      ],
      "to": [
        8.35,
        6.7,
        8.4
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          8,
          7,
          8.05
        ]
      },
      "faces": {
        "north": {
          "uv": [
            2.5,
            3,
            2.75,
            3.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            3,
            2.5,
            3.25,
            2.75
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            3,
            3,
            3.25,
            3.25
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            1,
            3.5,
            1.25,
            3.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            3.75,
            1.25,
            3.5,
            1
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            1.75,
            3.5,
            1.5,
            3.75
          ],
          "texture": "#0"
        }
      }
    }
  ]
}
'@

# Change the registered item from a BlockItem to the two-click placement item.
$itemsPath = "src\main\java\net\droingo\decor\registry\DecorItems.java"
$itemsFull = Join-Path $ProjectRoot $itemsPath
$items = [System.IO.File]::ReadAllText($itemsFull)

if (-not $items.Contains("import net.droingo.decor.content.FairyLightsItem;")) {
    $items = $items.Replace(
        "import net.droingo.decor.content.WallDecorItem;",
        "import net.droingo.decor.content.WallDecorItem;`r`nimport net.droingo.decor.content.FairyLightsItem;"
    )
}

$oldRegistration = @'
    public static final DeferredItem<BlockItem> FAIRY_LIGHTS =
            ITEMS.register(
                    "fairy_lights",
                    () -> new BlockItem(
                            DecorBlocks.FAIRY_LIGHTS_TEST.get(),
                            new Item.Properties()
                    )
            );
'@

$newRegistration = @'
    public static final DeferredItem<Item> FAIRY_LIGHTS =
            ITEMS.register(
                    "fairy_lights",
                    () -> new FairyLightsItem(
                            new Item.Properties().stacksTo(16)
                    )
            );
'@

if ($items.Contains($oldRegistration)) {
    $items = $items.Replace($oldRegistration, $newRegistration)
} elseif (-not $items.Contains("new FairyLightsItem(")) {
    throw "Could not find the current FAIRY_LIGHTS item registration."
}

$items = $items.Replace("import net.minecraft.world.item.BlockItem;`r`n", "")
$items = $items.Replace("import net.minecraft.world.item.BlockItem;`n", "")

[System.IO.File]::WriteAllText(
    $itemsFull,
    $items,
    [System.Text.UTF8Encoding]::new($false)
)

# Register the three new component models and keep compatibility with the old test names.
$clientPath = "src\main\java\net\droingo\decor\client\DroingosDecorClient.java"
$clientFull = Join-Path $ProjectRoot $clientPath
$client = [System.IO.File]::ReadAllText($clientFull)

if (-not $client.Contains('"fairy_lights_wire"')) {
    $client = $client.Replace(
        '"fairy_lights_test_normal",',
        '"fairy_lights_wire",`r`n                "fairy_lights_bulb",`r`n                "fairy_lights_glow",`r`n                "fairy_lights_test_normal",'
    )
}

[System.IO.File]::WriteAllText(
    $clientFull,
    $client,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Files installed."
Write-Host "Backup: $backup"
Write-Host "Compiling..."

& .\gradlew.bat compileJava
if ($LASTEXITCODE -ne 0) {
    throw "Compilation failed. Upload the compile output and I will correct it."
}

Write-Host ""
Write-Host "Build passed."
Write-Host "Usage:"
Write-Host "  1. Hold Fairy Lights and right-click the first surface."
Write-Host "  2. Right-click the second surface, up to 16 blocks away."
Write-Host "  3. Right-click the invisible anchor at point A to cycle modes."
Write-Host "  4. Shift-right-click the anchor to cycle cable sag."
Write-Host "  5. Hold Shift while choosing point B for a taut cable."
