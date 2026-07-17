$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$ProjectRoot = (Get-Location).Path
$BackupRoot = Join-Path $ProjectRoot (".hanging_sweater_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))

function Backup-File {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $Target = Join-Path $ProjectRoot $RelativePath

    if (Test-Path -LiteralPath $Target) {
        $Backup = Join-Path $BackupRoot $RelativePath
        $BackupDirectory = Split-Path -Parent $Backup
        New-Item -ItemType Directory -Force -Path $BackupDirectory | Out-Null
        Copy-Item -LiteralPath $Target -Destination $Backup -Force
    }
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Content
    )

    Backup-File $RelativePath

    $Target = Join-Path $ProjectRoot $RelativePath
    $Directory = Split-Path -Parent $Target
    New-Item -ItemType Directory -Force -Path $Directory | Out-Null

    [System.IO.File]::WriteAllText($Target, $Content, $Utf8NoBom)
}

function Write-Base64File {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Base64
    )

    Backup-File $RelativePath

    $Target = Join-Path $ProjectRoot $RelativePath
    $Directory = Split-Path -Parent $Target
    New-Item -ItemType Directory -Force -Path $Directory | Out-Null

    [System.IO.File]::WriteAllBytes(
        $Target,
        [Convert]::FromBase64String($Base64)
    )
}

if (!(Test-Path -LiteralPath (Join-Path $ProjectRoot "build.gradle"))) {
    throw "Run this script from the Droingo's Decor project root."
}

Write-Utf8NoBom "src/main/java/net/droingo/decor/api/GravityWallRenderDefinition.java" @'
package net.droingo.decor.api;

import net.minecraft.resources.ResourceLocation;
import org.joml.Vector3d;

import java.util.Objects;

/**
 * Models and pivot information for wall decor whose moving section aligns
 * toward world gravity while its mounting hardware stays fixed.
 */
public record GravityWallRenderDefinition(
        ResourceLocation fixedModel,
        ResourceLocation movingModel,
        Vector3d pivot,
        float scale
) {
    public GravityWallRenderDefinition {
        Objects.requireNonNull(fixedModel);
        Objects.requireNonNull(movingModel);
        Objects.requireNonNull(pivot);
    }
}
'@

Write-Utf8NoBom "src/main/java/net/droingo/decor/api/DecorDefinition.java" @'
package net.droingo.decor.api;

import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import org.jetbrains.annotations.Nullable;

import java.util.Objects;
import java.util.function.Supplier;

public final class DecorDefinition {
    private final ResourceLocation id;
    private final DecorCategory category;
    private final DecorPlacementType placementType;
    private final Supplier<? extends Item> itemSupplier;
    private final DecorInteraction interaction;

    private final double minX;
    private final double minY;
    private final double minZ;
    private final double maxX;
    private final double maxY;
    private final double maxZ;

    private final @Nullable BobbleheadRenderDefinition bobbleheadRender;
    private final @Nullable GravityWallRenderDefinition gravityWallRender;

    private DecorDefinition(Builder builder) {
        this.id = builder.id;
        this.category = builder.category;
        this.placementType = builder.placementType;
        this.itemSupplier = builder.itemSupplier;
        this.interaction = builder.interaction;

        this.minX = builder.minX;
        this.minY = builder.minY;
        this.minZ = builder.minZ;
        this.maxX = builder.maxX;
        this.maxY = builder.maxY;
        this.maxZ = builder.maxZ;

        this.bobbleheadRender = builder.bobbleheadRender;
        this.gravityWallRender = builder.gravityWallRender;
    }

    public static Builder builder(ResourceLocation id) {
        return new Builder(id);
    }

    public ResourceLocation id() {
        return id;
    }

    public DecorCategory category() {
        return category;
    }

    public DecorPlacementType placementType() {
        return placementType;
    }

    public DecorInteraction interaction() {
        return interaction;
    }

    public double minX() {
        return minX;
    }

    public double minY() {
        return minY;
    }

    public double minZ() {
        return minZ;
    }

    public double maxX() {
        return maxX;
    }

    public double maxY() {
        return maxY;
    }

    public double maxZ() {
        return maxZ;
    }

    public @Nullable BobbleheadRenderDefinition bobbleheadRender() {
        return bobbleheadRender;
    }

    public @Nullable GravityWallRenderDefinition gravityWallRender() {
        return gravityWallRender;
    }

    public ItemStack pickupStack() {
        return new ItemStack(itemSupplier.get());
    }

    public static final class Builder {
        private final ResourceLocation id;

        private DecorCategory category = DecorCategory.SMALL_DECOR;
        private DecorPlacementType placementType = DecorPlacementType.TINY;
        private Supplier<? extends Item> itemSupplier;
        private DecorInteraction interaction = DecorInteraction.NONE;

        private double minX = -0.125D;
        private double minY = 0.0D;
        private double minZ = -0.125D;
        private double maxX = 0.125D;
        private double maxY = 0.5D;
        private double maxZ = 0.125D;

        private BobbleheadRenderDefinition bobbleheadRender;
        private GravityWallRenderDefinition gravityWallRender;

        private Builder(ResourceLocation id) {
            this.id = Objects.requireNonNull(id);
        }

        public Builder category(DecorCategory category) {
            this.category = Objects.requireNonNull(category);
            return this;
        }

        public Builder placement(DecorPlacementType placementType) {
            this.placementType = Objects.requireNonNull(placementType);
            return this;
        }

        public Builder item(Supplier<? extends Item> itemSupplier) {
            this.itemSupplier = Objects.requireNonNull(itemSupplier);
            return this;
        }

        public Builder interaction(DecorInteraction interaction) {
            this.interaction = Objects.requireNonNull(interaction);
            return this;
        }

        public Builder bounds(
                double minX,
                double minY,
                double minZ,
                double maxX,
                double maxY,
                double maxZ
        ) {
            this.minX = minX;
            this.minY = minY;
            this.minZ = minZ;
            this.maxX = maxX;
            this.maxY = maxY;
            this.maxZ = maxZ;
            return this;
        }

        public Builder bobblehead(BobbleheadRenderDefinition renderDefinition) {
            this.bobbleheadRender = Objects.requireNonNull(renderDefinition);
            return this;
        }

        public Builder gravityWall(GravityWallRenderDefinition renderDefinition) {
            this.gravityWallRender = Objects.requireNonNull(renderDefinition);
            return this;
        }

        public DecorDefinition build() {
            if (itemSupplier == null) {
                throw new IllegalStateException(
                        "Decor definition " + id + " has no item supplier"
                );
            }

            if (bobbleheadRender != null && gravityWallRender != null) {
                throw new IllegalStateException(
                        "Decor definition " + id
                                + " cannot use two render behaviours"
                );
            }

            return new DecorDefinition(this);
        }
    }
}
'@

Write-Utf8NoBom "src/main/java/net/droingo/decor/content/WallDecorBlockEntity.java" @'
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
import org.jetbrains.annotations.Nullable;

public final class WallDecorBlockEntity extends BlockEntity {
    private @Nullable ResourceLocation decorId;

    public WallDecorBlockEntity(BlockPos pos, BlockState state) {
        super(DecorBlockEntities.WALL_DECOR_CONTAINER.get(), pos, state);
    }

    public @Nullable ResourceLocation getDecorId() {
        return decorId;
    }

    public void setDecorId(ResourceLocation decorId) {
        this.decorId = decorId;
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

        if (decorId != null) {
            tag.putString("Decor", decorId.toString());
        }
    }

    @Override
    protected void loadAdditional(
            CompoundTag tag,
            HolderLookup.Provider registries
    ) {
        super.loadAdditional(tag, registries);
        decorId = tag.contains("Decor")
                ? ResourceLocation.tryParse(tag.getString("Decor"))
                : null;
    }

    @Override
    public CompoundTag getUpdateTag(HolderLookup.Provider registries) {
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
            Connection connection,
            ClientboundBlockEntityDataPacket packet,
            HolderLookup.Provider registries
    ) {
        super.onDataPacket(connection, packet, registries);
    }
}
'@

Write-Utf8NoBom "src/main/java/net/droingo/decor/content/WallDecorBlock.java" @'
package net.droingo.decor.content;

import com.mojang.serialization.MapCodec;
import net.droingo.decor.api.DecorDefinition;
import net.droingo.decor.registry.DecorDefinitionRegistry;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.BaseEntityBlock;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.block.state.properties.DirectionProperty;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;
import org.jetbrains.annotations.Nullable;

public final class WallDecorBlock extends BaseEntityBlock {
    public static final MapCodec<WallDecorBlock> CODEC =
            simpleCodec(WallDecorBlock::new);

    public static final DirectionProperty FACING =
            BlockStateProperties.HORIZONTAL_FACING;

    private static final VoxelShape NORTH_SHAPE =
            Shapes.box(0.0D, 0.0D, 0.0D, 1.0D, 1.0D, 2.0D / 16.0D);

    private static final VoxelShape SOUTH_SHAPE =
            Shapes.box(0.0D, 0.0D, 14.0D / 16.0D, 1.0D, 1.0D, 1.0D);

    private static final VoxelShape WEST_SHAPE =
            Shapes.box(0.0D, 0.0D, 0.0D, 2.0D / 16.0D, 1.0D, 1.0D);

    private static final VoxelShape EAST_SHAPE =
            Shapes.box(14.0D / 16.0D, 0.0D, 0.0D, 1.0D, 1.0D, 1.0D);

    public WallDecorBlock(Properties properties) {
        super(properties);
        registerDefaultState(stateDefinition.any().setValue(FACING, Direction.SOUTH));
    }

    @Override
    protected MapCodec<? extends BaseEntityBlock> codec() {
        return CODEC;
    }

    @Override
    protected void createBlockStateDefinition(
            StateDefinition.Builder<net.minecraft.world.level.block.Block, BlockState> builder
    ) {
        builder.add(FACING);
    }

    @Override
    public RenderShape getRenderShape(BlockState state) {
        return RenderShape.INVISIBLE;
    }

    @Nullable
    @Override
    public BlockEntity newBlockEntity(BlockPos pos, BlockState state) {
        return new WallDecorBlockEntity(pos, state);
    }

    @Override
    protected float getDestroyProgress(
            BlockState state,
            Player player,
            BlockGetter level,
            BlockPos pos
    ) {
        return 0.0F;
    }

    @Override
    protected VoxelShape getShape(
            BlockState state,
            BlockGetter level,
            BlockPos pos,
            CollisionContext context
    ) {
        return switch (state.getValue(FACING)) {
            case NORTH -> NORTH_SHAPE;
            case SOUTH -> SOUTH_SHAPE;
            case WEST -> WEST_SHAPE;
            case EAST -> EAST_SHAPE;
            default -> SOUTH_SHAPE;
        };
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

    @Override
    protected InteractionResult useWithoutItem(
            BlockState state,
            Level level,
            BlockPos pos,
            Player player,
            BlockHitResult hit
    ) {
        if (!(level.getBlockEntity(pos) instanceof WallDecorBlockEntity blockEntity)) {
            return InteractionResult.PASS;
        }

        DecorDefinition definition = blockEntity.getDecorId() == null
                ? null
                : DecorDefinitionRegistry.get(blockEntity.getDecorId());

        if (definition == null) {
            return InteractionResult.PASS;
        }

        /*
         * Wall decor has a fixed mounting direction, so sneak-use does not
         * rotate it. Normal use runs the decoration's own interaction.
         */
        if (player.isShiftKeyDown()) {
            return InteractionResult.sidedSuccess(level.isClientSide);
        }

        return definition.interaction().interact(
                level,
                pos,
                player,
                null,
                0
        );
    }

    @Override
    public void attack(
            BlockState state,
            Level level,
            BlockPos pos,
            Player player
    ) {
        super.attack(state, level, pos, player);

        if (
                level.isClientSide
                        || !(level.getBlockEntity(pos)
                        instanceof WallDecorBlockEntity blockEntity)
        ) {
            return;
        }

        DecorDefinition definition = blockEntity.getDecorId() == null
                ? null
                : DecorDefinitionRegistry.get(blockEntity.getDecorId());

        if (definition != null && !player.getAbilities().instabuild) {
            ItemStack stack = definition.pickupStack();

            if (!player.getInventory().add(stack)) {
                popResource(level, pos, stack);
            }
        }

        level.removeBlock(pos, false);
    }
}
'@

Write-Utf8NoBom "src/main/java/net/droingo/decor/content/WallDecorItem.java" @'
package net.droingo.decor.content;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.registry.DecorBlocks;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.context.UseOnContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.state.BlockState;

public final class WallDecorItem extends Item {
    private final ResourceLocation decorId;

    public WallDecorItem(String id, Properties properties) {
        super(properties);
        this.decorId = ResourceLocation.fromNamespaceAndPath(
                DroingosDecor.MOD_ID,
                id
        );
    }

    @Override
    public InteractionResult useOn(UseOnContext context) {
        Direction clickedFace = context.getClickedFace();

        if (!clickedFace.getAxis().isHorizontal()) {
            return InteractionResult.PASS;
        }

        Level level = context.getLevel();
        BlockPos placementPos = context.getClickedPos().relative(clickedFace);

        if (!level.getBlockState(placementPos).canBeReplaced()) {
            return InteractionResult.FAIL;
        }

        Direction supportDirection = clickedFace.getOpposite();

        BlockState placementState = DecorBlocks.WALL_DECOR_CONTAINER
                .get()
                .defaultBlockState()
                .setValue(WallDecorBlock.FACING, supportDirection);

        if (!level.isClientSide) {
            level.setBlock(placementPos, placementState, 3);

            if (
                    !(level.getBlockEntity(placementPos)
                    instanceof WallDecorBlockEntity blockEntity)
            ) {
                level.removeBlock(placementPos, false);
                return InteractionResult.FAIL;
            }

            blockEntity.setDecorId(decorId);

            if (
                    context.getPlayer() == null
                            || !context.getPlayer().getAbilities().instabuild
            ) {
                context.getItemInHand().shrink(1);
            }
        }

        return InteractionResult.sidedSuccess(level.isClientSide);
    }
}
'@

Write-Utf8NoBom "src/main/java/net/droingo/decor/client/animation/HangingGravityMotionState.java" @'
package net.droingo.decor.client.animation;

import net.minecraft.util.Mth;

/**
 * Smooth, non-oscillating gravity alignment for hanging wall decor.
 *
 * Unlike a bobblehead, this does not use a spring. It eases directly toward
 * the gravity-derived target and therefore settles without repeated wobbling.
 */
public final class HangingGravityMotionState {
    private static final float MAX_SIDE_ANGLE = 85.0F;
    private static final float MAX_AWAY_ANGLE = 80.0F;
    private static final float RESPONSE_PER_TICK = 0.28F;

    private boolean initialized;
    private double lastTimelineTime;

    private float sideAngle;
    private float awayAngle;

    public void update(
            double timelineTime,
            float targetSideAngle,
            float targetAwayAngle
    ) {
        targetSideAngle = Mth.clamp(
                targetSideAngle,
                -MAX_SIDE_ANGLE,
                MAX_SIDE_ANGLE
        );

        targetAwayAngle = Mth.clamp(
                targetAwayAngle,
                0.0F,
                MAX_AWAY_ANGLE
        );

        if (!initialized) {
            initialized = true;
            lastTimelineTime = timelineTime;
            sideAngle = targetSideAngle;
            awayAngle = targetAwayAngle;
            return;
        }

        double deltaTicks = timelineTime - lastTimelineTime;

        if (deltaTicks <= 0.0D || deltaTicks > 4.0D) {
            sideAngle = targetSideAngle;
            awayAngle = targetAwayAngle;
            lastTimelineTime = timelineTime;
            return;
        }

        float blend = 1.0F - (float) Math.pow(
                1.0F - RESPONSE_PER_TICK,
                deltaTicks
        );

        sideAngle = Mth.lerp(blend, sideAngle, targetSideAngle);
        awayAngle = Mth.lerp(blend, awayAngle, targetAwayAngle);

        if (Math.abs(sideAngle - targetSideAngle) < 0.01F) {
            sideAngle = targetSideAngle;
        }

        if (Math.abs(awayAngle - targetAwayAngle) < 0.01F) {
            awayAngle = targetAwayAngle;
        }

        lastTimelineTime = timelineTime;
    }

    public float getSideAngle() {
        return sideAngle;
    }

    public float getAwayAngle() {
        return awayAngle;
    }
}
'@

Write-Utf8NoBom "src/main/java/net/droingo/decor/client/render/WallDecorRenderer.java" @'
package net.droingo.decor.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;
import dev.ryanhcode.sable.Sable;
import net.droingo.decor.api.DecorDefinition;
import net.droingo.decor.api.GravityWallRenderDefinition;
import net.droingo.decor.client.animation.HangingGravityMotionState;
import net.droingo.decor.content.WallDecorBlock;
import net.droingo.decor.content.WallDecorBlockEntity;
import net.droingo.decor.registry.DecorDefinitionRegistry;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.block.BlockRenderDispatcher;
import net.minecraft.client.renderer.blockentity.BlockEntityRenderer;
import net.minecraft.client.renderer.blockentity.BlockEntityRendererProvider;
import net.minecraft.client.resources.model.BakedModel;
import net.minecraft.client.resources.model.ModelResourceLocation;
import net.minecraft.core.Direction;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.phys.Vec3;
import net.neoforged.neoforge.client.model.data.ModelData;
import org.joml.Vector3d;

import java.util.Map;
import java.util.WeakHashMap;

public final class WallDecorRenderer
        implements BlockEntityRenderer<WallDecorBlockEntity> {

    private final Map<WallDecorBlockEntity, HangingGravityMotionState> motionStates =
            new WeakHashMap<>();

    private final BlockRenderDispatcher blockRenderer;

    public WallDecorRenderer(BlockEntityRendererProvider.Context context) {
        this.blockRenderer = context.getBlockRenderDispatcher();
    }

    @Override
    public void render(
            WallDecorBlockEntity blockEntity,
            float partialTick,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        ResourceLocation id = blockEntity.getDecorId();

        if (id == null) {
            return;
        }

        DecorDefinition definition = DecorDefinitionRegistry.get(id);

        if (definition == null || definition.gravityWallRender() == null) {
            return;
        }

        GravityWallRenderDefinition render = definition.gravityWallRender();
        Direction supportDirection = blockEntity.getBlockState()
                .getValue(WallDecorBlock.FACING);

        float yawDegrees = yawForSupport(supportDirection);

        HangingGravityMotionState motion =
                motionStates.computeIfAbsent(
                        blockEntity,
                        ignored -> new HangingGravityMotionState()
                );

        updateGravityMotion(
                blockEntity,
                render,
                yawDegrees,
                partialTick,
                motion
        );

        poseStack.pushPose();

        poseStack.translate(0.5D, 0.5D, 0.5D);
        poseStack.mulPose(Axis.YP.rotationDegrees(yawDegrees));
        poseStack.translate(-0.5D, -0.5D, -0.5D);

        poseStack.scale(render.scale(), render.scale(), render.scale());

        renderModel(
                poseStack,
                buffers,
                render.fixedModel(),
                packedLight,
                packedOverlay
        );

        renderMovingModel(
                poseStack,
                buffers,
                render,
                motion,
                packedLight,
                packedOverlay
        );

        poseStack.popPose();
    }

    private void updateGravityMotion(
            WallDecorBlockEntity blockEntity,
            GravityWallRenderDefinition render,
            float yawDegrees,
            float partialTick,
            HangingGravityMotionState motion
    ) {
        Level level = blockEntity.getLevel();

        if (level == null) {
            return;
        }

        Vector3d pivot = render.pivot();

        double yawRadians = Math.toRadians(yawDegrees);
        double cos = Math.cos(yawRadians);
        double sin = Math.sin(yawRadians);

        double offsetX = pivot.x - 0.5D;
        double offsetZ = pivot.z - 0.5D;

        double rotatedOffsetX = offsetX * cos + offsetZ * sin;
        double rotatedOffsetZ = -offsetX * sin + offsetZ * cos;

        Vec3 localOrigin = new Vec3(
                blockEntity.getBlockPos().getX() + 0.5D + rotatedOffsetX,
                blockEntity.getBlockPos().getY() + pivot.y,
                blockEntity.getBlockPos().getZ() + 0.5D + rotatedOffsetZ
        );

        Vec3 worldOrigin =
                Sable.HELPER.projectOutOfSubLevel(level, localOrigin);

        Vec3 worldLocalX =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin.add(1.0D, 0.0D, 0.0D)
                ).subtract(worldOrigin);

        Vec3 worldLocalY =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin.add(0.0D, 1.0D, 0.0D)
                ).subtract(worldOrigin);

        Vec3 worldLocalZ =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin.add(0.0D, 0.0D, 1.0D)
                ).subtract(worldOrigin);

        if (
                worldLocalX.lengthSqr() < 0.000001D
                        || worldLocalY.lengthSqr() < 0.000001D
                        || worldLocalZ.lengthSqr() < 0.000001D
        ) {
            return;
        }

        worldLocalX = worldLocalX.normalize();
        worldLocalY = worldLocalY.normalize();
        worldLocalZ = worldLocalZ.normalize();

        Vec3 decorRight = worldLocalX.scale(cos)
                .add(worldLocalZ.scale(sin))
                .normalize();

        Vec3 decorUp = worldLocalY;

        /*
         * The model is authored against its local +Z wall face.
         * Local -Z therefore points away from the wall.
         */
        Vec3 towardWall = worldLocalX.scale(-sin)
                .add(worldLocalZ.scale(cos))
                .normalize();

        Vec3 awayFromWall = towardWall.scale(-1.0D);
        Vec3 gravity = new Vec3(0.0D, -1.0D, 0.0D);

        double downComponent = Math.max(
                0.0001D,
                gravity.dot(decorUp.scale(-1.0D))
        );

        double sideComponent = gravity.dot(decorRight);

        /*
         * Negative away movement would drive the cloth into the wall.
         * Clamp it to zero so the sweater may hang away from the wall but
         * never through it.
         */
        double awayComponent = Math.max(
                0.0D,
                gravity.dot(awayFromWall)
        );

        float targetSide = (float) Math.toDegrees(
                Math.atan2(sideComponent, downComponent)
        );

        float targetAway = (float) Math.toDegrees(
                Math.atan2(awayComponent, downComponent)
        );

        motion.update(
                level.getGameTime() + partialTick,
                targetSide,
                targetAway
        );
    }

    private void renderMovingModel(
            PoseStack poseStack,
            MultiBufferSource buffers,
            GravityWallRenderDefinition render,
            HangingGravityMotionState motion,
            int packedLight,
            int packedOverlay
    ) {
        Vector3d pivot = render.pivot();

        poseStack.pushPose();

        poseStack.translate(pivot.x, pivot.y, pivot.z);

        /*
         * X rotates the sweater away from the wall.
         * Z lets it remain vertically level when the vehicle rolls sideways.
         */
        poseStack.mulPose(
                Axis.XP.rotationDegrees(motion.getAwayAngle())
        );

        poseStack.mulPose(
                Axis.ZP.rotationDegrees(motion.getSideAngle())
        );

        poseStack.translate(-pivot.x, -pivot.y, -pivot.z);

        renderModel(
                poseStack,
                buffers,
                render.movingModel(),
                packedLight,
                packedOverlay
        );

        poseStack.popPose();
    }

    private void renderModel(
            PoseStack poseStack,
            MultiBufferSource buffers,
            ResourceLocation location,
            int light,
            int overlay
    ) {
        BakedModel model = Minecraft.getInstance()
                .getModelManager()
                .getModel(ModelResourceLocation.standalone(location));

        VertexConsumer consumer = buffers.getBuffer(RenderType.cutout());

        blockRenderer.getModelRenderer().renderModel(
                poseStack.last(),
                consumer,
                Blocks.AIR.defaultBlockState(),
                model,
                1.0F,
                1.0F,
                1.0F,
                light,
                overlay,
                ModelData.EMPTY,
                RenderType.cutout()
        );
    }

    private static float yawForSupport(Direction supportDirection) {
        return switch (supportDirection) {
            case SOUTH -> 0.0F;
            case EAST -> 90.0F;
            case NORTH -> 180.0F;
            case WEST -> -90.0F;
            default -> 0.0F;
        };
    }
}
'@

Write-Utf8NoBom "src/main/java/net/droingo/decor/registry/DecorBlocks.java" @'
package net.droingo.decor.registry;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.content.DecorContainerBlock;
import net.droingo.decor.content.WallDecorBlock;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.material.MapColor;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforge.registries.DeferredBlock;
import net.neoforged.neoforge.registries.DeferredRegister;

public final class DecorBlocks {
    public static final DeferredRegister.Blocks BLOCKS =
            DeferredRegister.createBlocks(DroingosDecor.MOD_ID);

    public static final DeferredBlock<DecorContainerBlock> DECOR_CONTAINER =
            BLOCKS.registerBlock(
                    "decor_container",
                    DecorContainerBlock::new,
                    BlockBehaviour.Properties.of()
                            .mapColor(MapColor.NONE)
                            .strength(0.2F)
                            .sound(SoundType.WOOD)
                            .noOcclusion()
                            .noCollission()
            );

    public static final DeferredBlock<WallDecorBlock> WALL_DECOR_CONTAINER =
            BLOCKS.registerBlock(
                    "wall_decor_container",
                    WallDecorBlock::new,
                    BlockBehaviour.Properties.of()
                            .mapColor(MapColor.NONE)
                            .strength(0.2F)
                            .sound(SoundType.WOOL)
                            .noOcclusion()
                            .noCollission()
            );

    private DecorBlocks() {
    }

    public static void register(IEventBus bus) {
        BLOCKS.register(bus);
    }
}
'@

Write-Utf8NoBom "src/main/java/net/droingo/decor/registry/DecorBlockEntities.java" @'
package net.droingo.decor.registry;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.content.DecorContainerBlockEntity;
import net.droingo.decor.content.WallDecorBlockEntity;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforge.registries.DeferredHolder;
import net.neoforged.neoforge.registries.DeferredRegister;

public final class DecorBlockEntities {
    public static final DeferredRegister<BlockEntityType<?>> TYPES =
            DeferredRegister.create(
                    BuiltInRegistries.BLOCK_ENTITY_TYPE,
                    DroingosDecor.MOD_ID
            );

    public static final DeferredHolder<
            BlockEntityType<?>,
            BlockEntityType<DecorContainerBlockEntity>
            > DECOR_CONTAINER = TYPES.register(
            "decor_container",
            () -> BlockEntityType.Builder.of(
                    DecorContainerBlockEntity::new,
                    DecorBlocks.DECOR_CONTAINER.get()
            ).build(null)
    );

    public static final DeferredHolder<
            BlockEntityType<?>,
            BlockEntityType<WallDecorBlockEntity>
            > WALL_DECOR_CONTAINER = TYPES.register(
            "wall_decor_container",
            () -> BlockEntityType.Builder.of(
                    WallDecorBlockEntity::new,
                    DecorBlocks.WALL_DECOR_CONTAINER.get()
            ).build(null)
    );

    private DecorBlockEntities() {
    }

    public static void register(IEventBus bus) {
        TYPES.register(bus);
    }
}
'@

Write-Utf8NoBom "src/main/java/net/droingo/decor/registry/DecorDefinitionRegistry.java" @'
package net.droingo.decor.registry;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.api.BobbleheadRenderDefinition;
import net.droingo.decor.api.DecorCategory;
import net.droingo.decor.api.DecorDefinition;
import net.droingo.decor.api.DecorPlacementType;
import net.droingo.decor.api.GravityWallRenderDefinition;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import org.joml.Vector3d;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class DecorDefinitionRegistry {
    private static final Map<ResourceLocation, DecorDefinition> DEFINITIONS =
            new LinkedHashMap<>();

    private static final List<String> SWEATER_QUIPS = List.of(
            "It smells bad.",
            "Has this ever been washed?",
            "It is still damp.",
            "Whose sweater is this?",
            "There is something in the pocket.",
            "It has seen better days.",
            "You probably should not wear this.",
            "It smells vaguely familiar.",
            "That stain is permanent.",
            "Maybe leave it where it is."
    );

    private static boolean bootstrapped;

    private DecorDefinitionRegistry() {
    }

    public static void bootstrap() {
        if (bootstrapped) {
            return;
        }

        bootstrapped = true;

        ResourceLocation parrotId = id("bobble_parrot");

        register(
                DecorDefinition.builder(parrotId)
                        .category(DecorCategory.BOBBLEHEADS)
                        .placement(DecorPlacementType.TINY)
                        .item(DecorItems.BOBBLE_PARROT::get)
                        .bounds(
                                -0.118D,
                                0.0D,
                                -0.238D,
                                0.118D,
                                0.755D,
                                0.141D
                        )
                        .bobblehead(
                                new BobbleheadRenderDefinition(
                                        model("bobble_parrot_body"),
                                        model("bobble_parrot_head"),
                                        new Vector3d(
                                                8.0D / 16.0D,
                                                3.2D / 16.0D,
                                                7.3D / 16.0D
                                        ),
                                        1.5F
                                )
                        )
                        .interaction((level, pos, player, container, slot) -> {
                            if (!level.isClientSide) {
                                float pitch =
                                        1.45F
                                                + level.random.nextFloat()
                                                * 0.25F;

                                level.playSound(
                                        null,
                                        pos,
                                        SoundEvents.PARROT_AMBIENT,
                                        SoundSource.BLOCKS,
                                        0.85F,
                                        pitch
                                );
                            }

                            return net.minecraft.world.InteractionResult
                                    .sidedSuccess(level.isClientSide);
                        })
                        .build()
        );

        ResourceLocation sweaterId = id("hanging_sweater");

        register(
                DecorDefinition.builder(sweaterId)
                        .category(DecorCategory.WALL_DECOR)
                        .placement(DecorPlacementType.WALL)
                        .item(DecorItems.HANGING_SWEATER::get)
                        .gravityWall(
                                new GravityWallRenderDefinition(
                                        model("hanging_sweater_nail"),
                                        model("hanging_sweater_cloth"),
                                        new Vector3d(
                                                8.0D / 16.0D,
                                                14.6D / 16.0D,
                                                15.0D / 16.0D
                                        ),
                                        1.0F
                                )
                        )
                        .interaction((level, pos, player, container, slot) -> {
                            if (!level.isClientSide) {
                                String quip = SWEATER_QUIPS.get(
                                        level.random.nextInt(
                                                SWEATER_QUIPS.size()
                                        )
                                );

                                player.displayClientMessage(
                                        Component.literal(quip),
                                        true
                                );
                            }

                            return net.minecraft.world.InteractionResult
                                    .sidedSuccess(level.isClientSide);
                        })
                        .build()
        );
    }

    public static DecorDefinition register(DecorDefinition definition) {
        DecorDefinition previous =
                DEFINITIONS.putIfAbsent(definition.id(), definition);

        if (previous != null) {
            throw new IllegalStateException(
                    "Duplicate decor definition: " + definition.id()
            );
        }

        return definition;
    }

    public static DecorDefinition get(ResourceLocation id) {
        return DEFINITIONS.get(id);
    }

    public static Collection<DecorDefinition> all() {
        return List.copyOf(DEFINITIONS.values());
    }

    public static List<DecorDefinition> creativeOrder() {
        List<DecorDefinition> ordered =
                new ArrayList<>(DEFINITIONS.values());

        ordered.sort(
                Comparator
                        .comparingInt(
                                (DecorDefinition definition) ->
                                        definition.category().order()
                        )
                        .thenComparing(
                                definition ->
                                        definition.id().toString()
                        )
        );

        return ordered;
    }

    private static ResourceLocation id(String path) {
        return ResourceLocation.fromNamespaceAndPath(
                DroingosDecor.MOD_ID,
                path
        );
    }

    private static ResourceLocation model(String path) {
        return ResourceLocation.fromNamespaceAndPath(
                DroingosDecor.MOD_ID,
                "block/" + path
        );
    }
}
'@

Write-Utf8NoBom "src/main/java/net/droingo/decor/client/DroingosDecorClient.java" @'
package net.droingo.decor.client;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.api.BobbleheadRenderDefinition;
import net.droingo.decor.api.DecorDefinition;
import net.droingo.decor.api.GravityWallRenderDefinition;
import net.droingo.decor.client.render.DecorContainerRenderer;
import net.droingo.decor.client.render.WallDecorRenderer;
import net.droingo.decor.registry.DecorBlockEntities;
import net.droingo.decor.registry.DecorDefinitionRegistry;
import net.minecraft.client.resources.model.ModelResourceLocation;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.client.event.EntityRenderersEvent;
import net.neoforged.neoforge.client.event.ModelEvent;

@EventBusSubscriber(
        modid = DroingosDecor.MOD_ID,
        value = Dist.CLIENT,
        bus = EventBusSubscriber.Bus.MOD
)
public final class DroingosDecorClient {
    private DroingosDecorClient() {
    }

    @SubscribeEvent
    public static void registerBlockEntityRenderers(
            EntityRenderersEvent.RegisterRenderers event
    ) {
        event.registerBlockEntityRenderer(
                DecorBlockEntities.DECOR_CONTAINER.get(),
                DecorContainerRenderer::new
        );

        event.registerBlockEntityRenderer(
                DecorBlockEntities.WALL_DECOR_CONTAINER.get(),
                WallDecorRenderer::new
        );
    }

    @SubscribeEvent
    public static void registerAdditionalModels(
            ModelEvent.RegisterAdditional event
    ) {
        for (DecorDefinition definition : DecorDefinitionRegistry.all()) {
            BobbleheadRenderDefinition bobblehead =
                    definition.bobbleheadRender();

            if (bobblehead != null) {
                event.register(
                        ModelResourceLocation.standalone(
                                bobblehead.bodyModel()
                        )
                );

                event.register(
                        ModelResourceLocation.standalone(
                                bobblehead.movingModel()
                        )
                );
            }

            GravityWallRenderDefinition gravityWall =
                    definition.gravityWallRender();

            if (gravityWall != null) {
                event.register(
                        ModelResourceLocation.standalone(
                                gravityWall.fixedModel()
                        )
                );

                event.register(
                        ModelResourceLocation.standalone(
                                gravityWall.movingModel()
                        )
                );
            }
        }
    }
}
'@

$DecorItemsPath = Join-Path $ProjectRoot "src/main/java/net/droingo/decor/registry/DecorItems.java"
$DecorItems = [System.IO.File]::ReadAllText($DecorItemsPath)

if ($DecorItems -notmatch "WallDecorItem") {
    $DecorItems = $DecorItems.Replace(
        "import net.droingo.decor.content.TinyDecorItem;",
        "import net.droingo.decor.content.TinyDecorItem;`r`nimport net.droingo.decor.content.WallDecorItem;"
    )
}

if ($DecorItems -notmatch "HANGING_SWEATER") {
    $Registration = @'

    public static final DeferredItem<Item> HANGING_SWEATER = ITEMS.register(
            "hanging_sweater",
            () -> new WallDecorItem(
                    "hanging_sweater",
                    new Item.Properties()
            )
    );
'@

    $DecorItems = $DecorItems.Replace(
        "    private DecorItems()",
        $Registration + "`r`n    private DecorItems()"
    )
}

Backup-File "src/main/java/net/droingo/decor/registry/DecorItems.java"
[System.IO.File]::WriteAllText(
    $DecorItemsPath,
    $DecorItems,
    $Utf8NoBom
)

Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/block/hanging_sweater_nail.json" @'
{
  "format_version": "1.9.0",
  "credit": "Made with Blockbench",
  "texture_size": [
    32,
    32
  ],
  "textures": {
    "0": "droingos_decor:block/hanging_sweater",
    "particle": "droingos_decor:block/hanging_sweater"
  },
  "elements": [
    {
      "from": [
        7.5,
        14,
        14
      ],
      "to": [
        8.5,
        15,
        17
      ],
      "rotation": {
        "angle": 22.5,
        "axis": "x",
        "origin": [
          6.5,
          14,
          14
        ]
      },
      "faces": {
        "north": {
          "uv": [
            8,
            6,
            8.5,
            6.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            8,
            2,
            9.5,
            2.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            8,
            6.5,
            8.5,
            7
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            8,
            2.5,
            9.5,
            3
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            8.5,
            4.5,
            8,
            3
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            8.5,
            4.5,
            8,
            6
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        7.2,
        13.8,
        14
      ],
      "to": [
        8.7,
        15.3,
        14
      ],
      "rotation": {
        "angle": 22.5,
        "axis": "x",
        "origin": [
          6.5,
          14,
          14
        ]
      },
      "faces": {
        "north": {
          "uv": [
            8,
            0,
            9,
            1
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            1
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            8,
            1,
            9,
            2
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            1
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            1,
            0,
            0,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            1,
            0,
            0,
            0
          ],
          "texture": "#0"
        }
      }
    }
  ]
}
'@

Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/block/hanging_sweater_cloth.json" @'
{
  "format_version": "1.9.0",
  "credit": "Made with Blockbench",
  "texture_size": [
    32,
    32
  ],
  "textures": {
    "0": "droingos_decor:block/hanging_sweater",
    "particle": "droingos_decor:block/hanging_sweater"
  },
  "elements": [
    {
      "from": [
        0,
        -0.3,
        15
      ],
      "to": [
        16,
        15.7,
        15
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          8,
          14.6,
          15
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            8,
            8
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            8
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            8,
            8,
            16
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            8
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            8,
            0,
            0,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            8,
            0,
            0,
            0
          ],
          "texture": "#0"
        }
      }
    }
  ]
}
'@

Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/block/hanging_sweater_full.json" @'
{
  "format_version": "1.9.0",
  "credit": "Made with Blockbench",
  "texture_size": [
    32,
    32
  ],
  "textures": {
    "0": "droingos_decor:block/hanging_sweater",
    "particle": "droingos_decor:block/hanging_sweater"
  },
  "elements": [
    {
      "from": [
        7.5,
        14,
        14
      ],
      "to": [
        8.5,
        15,
        17
      ],
      "rotation": {
        "angle": 22.5,
        "axis": "x",
        "origin": [
          6.5,
          14,
          14
        ]
      },
      "faces": {
        "north": {
          "uv": [
            8,
            6,
            8.5,
            6.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            8,
            2,
            9.5,
            2.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            8,
            6.5,
            8.5,
            7
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            8,
            2.5,
            9.5,
            3
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            8.5,
            4.5,
            8,
            3
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            8.5,
            4.5,
            8,
            6
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        7.2,
        13.8,
        14
      ],
      "to": [
        8.7,
        15.3,
        14
      ],
      "rotation": {
        "angle": 22.5,
        "axis": "x",
        "origin": [
          6.5,
          14,
          14
        ]
      },
      "faces": {
        "north": {
          "uv": [
            8,
            0,
            9,
            1
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            1
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            8,
            1,
            9,
            2
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            1
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            1,
            0,
            0,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            1,
            0,
            0,
            0
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        0,
        -0.3,
        15
      ],
      "to": [
        16,
        15.7,
        15
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          8,
          14.6,
          15
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            8,
            8
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            8
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            8,
            8,
            16
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            8
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            8,
            0,
            0,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            8,
            0,
            0,
            0
          ],
          "texture": "#0"
        }
      }
    }
  ]
}
'@

Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/hanging_sweater.json" @'
{
  "parent": "droingos_decor:block/hanging_sweater_full",
  "display": {
    "gui": {
      "rotation": [
        0,
        180,
        0
      ],
      "translation": [
        0,
        0,
        0
      ],
      "scale": [
        0.75,
        0.75,
        0.75
      ]
    },
    "ground": {
      "translation": [
        0,
        3,
        0
      ],
      "scale": [
        0.5,
        0.5,
        0.5
      ]
    },
    "fixed": {
      "rotation": [
        0,
        180,
        0
      ],
      "scale": [
        0.75,
        0.75,
        0.75
      ]
    },
    "thirdperson_righthand": {
      "rotation": [
        0,
        180,
        0
      ],
      "translation": [
        0,
        2,
        1
      ],
      "scale": [
        0.6,
        0.6,
        0.6
      ]
    },
    "firstperson_righthand": {
      "rotation": [
        0,
        180,
        0
      ],
      "translation": [
        0,
        2,
        1
      ],
      "scale": [
        0.6,
        0.6,
        0.6
      ]
    }
  }
}
'@

Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/block/wall_decor_container.json" @'
{
  "elements": []
}
'@

Write-Utf8NoBom "src/main/resources/assets/droingos_decor/blockstates/wall_decor_container.json" @'
{
  "variants": {
    "facing=north": {
      "model": "droingos_decor:block/wall_decor_container"
    },
    "facing=south": {
      "model": "droingos_decor:block/wall_decor_container"
    },
    "facing=east": {
      "model": "droingos_decor:block/wall_decor_container"
    },
    "facing=west": {
      "model": "droingos_decor:block/wall_decor_container"
    }
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/block/hanging_sweater.png" `
    "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAADyklEQVR4AbRWTUhUURQ+7/rGGX2TM+X/pP3/EbVqE4miomDQQvohjf5o3yIUBEEUTUFQWrRqE0FERiIGLlxIhVG0advCpNJk8F9HHZ1x3ni7360bwTRD3lfD3Hfeu++e833nnHvuO4xS/Jqbm3lXVxdPsYRuVpzkN8pPpFyTSj8pAQCLYQgShpBJATY2NigUCqXCSPkuKQEAK81YLKZuEyTnnDIyMhLm/3aCVdVV8PLzpfxq02V+7lYNP3u9Wg4YgOc9PT28tbXVKKst4RgXb9dyjJprVRy6jDFyuVyk+2OmK432Hd9D88EF8lgesnyZFF5Zp7o7Fzii0NjYaODel72DAvsLyOuz5MgJZFNOYTatrq4SonCl5GjSNFGKnyBgkh2zyZ/jp7XlNbI344Rn6FTXV/LKS2U8sh6lheklsm0b07Q8F6KpT0Ganpghn89H4XCYIpGIfLfdC4Mn8B6KXr+XZqfmKK8oV4JFN6KCTFxGBO8xpsaDZKabVHQ4IOXW1hYNfJgwMPB+u4PBILw309OkrukyaWVxhRAJKytTht2TmS5JheZXyZPpJtM0hfezhPQh/FJR88JgUIUW9zCKCICQHYtT8Ms0QYKURxBBxDyWm4oOBQjEUYaa2FKN2SL/8AhpgNdpwrvJsSma/TYvPdyVv1OmwBZk3MJ7qSUua6GwSEEaWZYlnvT/gkBchHOGCvbmSyvIe+BAAbkz3PIZnqsKAMGvHycJ4Gtiw4K04xT4c32yDIHmEaHNK84hACHcmAMRlCUqYXFmSa4FOPYK0uGYAIzBE4DBs+DnaVkJVpYlzwTMIy2IDCJhi5R5RbWAAPSevR83sEZ3MBjDAQRw1DcMAzy08KMS4H14ReRbHFiR9U0ZHewZrEUE6s8c4brg0GPKGE44TCDk8BYE5JkgUgJCiIIlyhJrcAB5/ZY8PZ++G3MWgb57/cZI3yvj0d0nUu4+WEjYByjF7AJRAaF1iv88AbEHsP71wBtj6OGwMfx4xBE4nEn4GoJI//0XxuCDIeNU8WkqPVZBL5+PyufRwbeOAQH6+0ggoF62t7fztrY22Q90dHQ4yrOy+SeZlEA0Gv21vqWl5Z97rown7Qc6OzuN7u5u3tvbK71HL4CBXgBD9QPKkK5kOPuT9QNNTU1GQ0NDyn5AF1jpCQLO+gFlSFc67gd0gZWe435AGdKVjvsBXWClJz7HNuE4xocFX0EcudvpB5QhXSkIOOsHdIGVHnPaDyhDupI57Qd0gZWe435AGdKVDBsQzYVuP6ALrPQYvu//sx9QQMnkdwAAAP//Wh4U2wAAAAZJREFUAwDit6Amdg8zXAAAAABJRU5ErkJggg=="

$LangPath = Join-Path $ProjectRoot "src/main/resources/assets/droingos_decor/lang/en_us.json"
$Lang = @{}

if (Test-Path -LiteralPath $LangPath) {
    $ExistingLang = [System.IO.File]::ReadAllText($LangPath)

    if (![string]::IsNullOrWhiteSpace($ExistingLang)) {
        $ExistingObject = $ExistingLang | ConvertFrom-Json

        foreach ($Property in $ExistingObject.PSObject.Properties) {
            $Lang[$Property.Name] = $Property.Value
        }
    }
}

$Lang["item.droingos_decor.hanging_sweater"] = "Hanging Sweater"
$Lang["block.droingos_decor.wall_decor_container"] = "Wall Decor Container"

$OrderedLang = [ordered]@{}

foreach ($Key in ($Lang.Keys | Sort-Object)) {
    $OrderedLang[$Key] = $Lang[$Key]
}

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/lang/en_us.json" `
    ($OrderedLang | ConvertTo-Json -Depth 5)

Write-Host ""
Write-Host "Hanging Sweater installed."
Write-Host "Backup directory: $BackupRoot"
Write-Host ""
Write-Host "Building..."
Write-Host ""

& .\gradlew.bat build

if ($LASTEXITCODE -ne 0) {
    throw "Build failed. Original files are available in: $BackupRoot"
}

Write-Host ""
Write-Host "Build successful."
Write-Host "The Hanging Sweater should appear under Wall Decor."
