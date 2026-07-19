$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Root = (Get-Location).Path

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $FullPath = Join-Path $Root $Path
    $Directory = Split-Path -Parent $FullPath

    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    }

    [System.IO.File]::WriteAllText($FullPath, $Content, $Utf8NoBom)
}

Write-Utf8NoBom "src/main/java/net/droingo/decor/client/animation/BeastSkullJawMotionState.java" @'
package net.droingo.decor.client.animation;

import net.minecraft.util.Mth;
import net.minecraft.world.phys.Vec3;

import java.util.Arrays;

public final class BeastSkullJawMotionState {
    private static final float MAX_ANGLE = 18.0F;
    private static final float SPRING = 0.18F;
    private static final float DAMPING = 0.90F;
    private static final float MAX_SPEED = 5.0F;

    private static final double INERTIA = 140.0D;
    private static final double DEAD_ZONE = 0.0015D;
    private static final double MAX_SAMPLE_SPEED = 8.0D;
    private static final double MAX_ACCELERATION = 1.25D;

    private static final int FILTER_SIZE = 5;
    private static final double POSITION_EPSILON_SQR = 1.0E-12D;
    private static final double MAX_SAMPLE_GAP_SECONDS = 0.50D;
    private static final double MAX_RENDER_GAP_SECONDS = 0.25D;

    private boolean initialized;
    private double lastRenderSeconds;
    private double lastMotionSampleSeconds;

    private Vec3 lastPosition = Vec3.ZERO;
    private Vec3 lastFilteredVelocity = Vec3.ZERO;
    private Vec3 acceleration = Vec3.ZERO;

    private final Vec3[] velocitySamples = new Vec3[FILTER_SIZE];
    private int sampleCount;
    private int sampleIndex;

    private float targetAngle;
    private float angle;
    private float angularVelocity;

    public void update(
            double seconds,
            Vec3 worldPosition,
            Vec3 localForward
    ) {
        if (!Double.isFinite(seconds) || !finite(worldPosition)) {
            return;
        }

        if (!initialized) {
            reset(seconds, worldPosition);
            return;
        }

        double frameSeconds = seconds - lastRenderSeconds;

        if (frameSeconds <= 0.0D || frameSeconds > MAX_RENDER_GAP_SECONDS) {
            reset(seconds, worldPosition);
            return;
        }

        Vec3 delta = worldPosition.subtract(lastPosition);

        if (delta.lengthSqr() > POSITION_EPSILON_SQR) {
            double sampleSeconds = seconds - lastMotionSampleSeconds;

            if (sampleSeconds > 0.0D && sampleSeconds <= MAX_SAMPLE_GAP_SECONDS) {
                sampleMotion(worldPosition, sampleSeconds);
            } else {
                clearFilter();
                lastFilteredVelocity = Vec3.ZERO;
                acceleration = Vec3.ZERO;
            }

            lastPosition = worldPosition;
            lastMotionSampleSeconds = seconds;
        } else {
            acceleration = acceleration.scale(
                    Math.pow(0.72D, frameSeconds * 20.0D)
            );
        }

        Vec3 forward = localForward.lengthSqr() < 0.000001D
                ? new Vec3(0.0D, 0.0D, 1.0D)
                : localForward.normalize();

        targetAngle = Mth.clamp(
                (float) (-acceleration.dot(forward) * INERTIA),
                -MAX_ANGLE,
                MAX_ANGLE
        );

        integrate((float) (frameSeconds * 20.0D));
        lastRenderSeconds = seconds;
    }

    private void sampleMotion(
            Vec3 worldPosition,
            double sampleSeconds
    ) {
        double sampleTicks = sampleSeconds * 20.0D;

        if (sampleTicks <= 0.0001D) {
            return;
        }

        Vec3 velocity = worldPosition
                .subtract(lastPosition)
                .scale(1.0D / sampleTicks);

        if (velocity.lengthSqr() > MAX_SAMPLE_SPEED * MAX_SAMPLE_SPEED) {
            clearFilter();
            lastFilteredVelocity = Vec3.ZERO;
            acceleration = Vec3.ZERO;
            return;
        }

        addSample(velocity);

        Vec3 filtered = filteredVelocity();

        Vec3 newAcceleration = filtered
                .subtract(lastFilteredVelocity)
                .scale(1.0D / sampleTicks);

        double length = newAcceleration.length();

        if (length < DEAD_ZONE) {
            newAcceleration = Vec3.ZERO;
        } else if (length > MAX_ACCELERATION) {
            newAcceleration = newAcceleration.scale(MAX_ACCELERATION / length);
        }

        acceleration = newAcceleration;
        lastFilteredVelocity = filtered;
    }

    private void integrate(float ticks) {
        ticks = Mth.clamp(ticks, 0.0F, 2.0F);

        angularVelocity +=
                (targetAngle - angle)
                        * SPRING
                        * ticks;

        angularVelocity *= (float) Math.pow(DAMPING, ticks);
        angularVelocity = Mth.clamp(
                angularVelocity,
                -MAX_SPEED,
                MAX_SPEED
        );

        angle += angularVelocity * ticks;
        angle = Mth.clamp(angle, -MAX_ANGLE, MAX_ANGLE);
    }

    private void addSample(Vec3 velocity) {
        velocitySamples[sampleIndex] = velocity;
        sampleIndex = (sampleIndex + 1) % FILTER_SIZE;

        if (sampleCount < FILTER_SIZE) {
            sampleCount++;
        }
    }

    private Vec3 filteredVelocity() {
        if (sampleCount == 0) {
            return Vec3.ZERO;
        }

        if (sampleCount < FILTER_SIZE) {
            Vec3 total = Vec3.ZERO;

            for (int i = 0; i < sampleCount; i++) {
                total = total.add(velocitySamples[i]);
            }

            return total.scale(1.0D / sampleCount);
        }

        double[] x = new double[FILTER_SIZE];
        double[] y = new double[FILTER_SIZE];
        double[] z = new double[FILTER_SIZE];

        for (int i = 0; i < FILTER_SIZE; i++) {
            Vec3 sample = velocitySamples[i];
            x[i] = sample.x;
            y[i] = sample.y;
            z[i] = sample.z;
        }

        Arrays.sort(x);
        Arrays.sort(y);
        Arrays.sort(z);

        int middle = FILTER_SIZE / 2;

        return new Vec3(
                x[middle],
                y[middle],
                z[middle]
        );
    }

    private void clearFilter() {
        Arrays.fill(velocitySamples, Vec3.ZERO);
        sampleCount = 0;
        sampleIndex = 0;
    }

    private void reset(
            double seconds,
            Vec3 worldPosition
    ) {
        initialized = true;
        lastRenderSeconds = seconds;
        lastMotionSampleSeconds = seconds;
        lastPosition = worldPosition;
        lastFilteredVelocity = Vec3.ZERO;
        acceleration = Vec3.ZERO;
        targetAngle = 0.0F;
        angularVelocity = 0.0F;
        clearFilter();
    }

    private static boolean finite(Vec3 value) {
        return Double.isFinite(value.x)
                && Double.isFinite(value.y)
                && Double.isFinite(value.z);
    }

    public float getAngle() {
        return angle;
    }
}
'@

Write-Utf8NoBom "src/main/java/net/droingo/decor/content/BeastSkullItem.java" @'
package net.droingo.decor.content;

import net.droingo.decor.registry.DecorBlocks;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.util.Mth;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.context.UseOnContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.state.BlockState;

public final class BeastSkullItem extends Item {
    public BeastSkullItem(Properties properties) {
        super(properties);
    }

    @Override
    public InteractionResult useOn(UseOnContext context) {
        Level level = context.getLevel();
        Direction clickedFace = context.getClickedFace();
        BlockPos pos = context.getClickedPos().relative(clickedFace);

        if (!level.getBlockState(pos).canBeReplaced()) {
            return InteractionResult.FAIL;
        }

        BeastSkullPlacement placement =
                clickedFace == Direction.UP
                        ? BeastSkullPlacement.FLOOR
                        : clickedFace == Direction.DOWN
                        ? BeastSkullPlacement.CEILING
                        : BeastSkullPlacement.WALL;

        Direction facing =
                placement == BeastSkullPlacement.WALL
                        ? clickedFace
                        : context.getHorizontalDirection().getOpposite();

        int rotation =
                Mth.floor(
                        (
                                context.getRotation()
                                        + 11.25F
                        ) / 22.5F
                ) & 15;

        BlockState state =
                DecorBlocks.THE_BEAST_SKULL
                        .get()
                        .defaultBlockState()
                        .setValue(
                                BeastSkullBlock.PLACEMENT,
                                placement
                        )
                        .setValue(
                                BeastSkullBlock.FACING,
                                facing
                        )
                        .setValue(
                                BeastSkullBlock.ROTATION,
                                rotation
                        );

        if (!state.canSurvive(level, pos)) {
            return InteractionResult.FAIL;
        }

        if (!level.isClientSide) {
            level.setBlock(pos, state, 3);

            if (
                    context.getPlayer() == null
                            || !context.getPlayer()
                            .getAbilities()
                            .instabuild
            ) {
                context.getItemInHand().shrink(1);
            }
        }

        return InteractionResult.sidedSuccess(
                level.isClientSide
        );
    }
}
'@

Write-Utf8NoBom "src/main/java/net/droingo/decor/content/BeastSkullBlock.java" @'
package net.droingo.decor.content;

import com.mojang.serialization.MapCodec;
import net.droingo.decor.entity.BeastSkullSeatEntity;
import net.droingo.decor.registry.DecorEntities;
import net.droingo.decor.registry.DecorItems;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.LevelReader;
import net.minecraft.world.level.block.BaseEntityBlock;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.SupportType;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.entity.BlockEntityTicker;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.block.state.properties.DirectionProperty;
import net.minecraft.world.level.block.state.properties.EnumProperty;
import net.minecraft.world.level.block.state.properties.IntegerProperty;
import net.minecraft.world.level.material.PushReaction;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;
import org.jetbrains.annotations.Nullable;

public final class BeastSkullBlock extends BaseEntityBlock {
    public static final MapCodec<BeastSkullBlock> CODEC =
            simpleCodec(BeastSkullBlock::new);

    public static final DirectionProperty FACING =
            net.minecraft.world.level.block.HorizontalDirectionalBlock.FACING;

    public static final IntegerProperty ROTATION =
            BlockStateProperties.ROTATION_16;

    public static final EnumProperty<BeastSkullPlacement> PLACEMENT =
            EnumProperty.create(
                    "placement",
                    BeastSkullPlacement.class
            );

    private static final VoxelShape FLOOR_SHAPE =
            Shapes.box(
                    0.0D,
                    0.0D,
                    0.0D,
                    1.0D,
                    1.0D,
                    1.0D
            );

    private static final VoxelShape WALL_SHAPE =
            Shapes.box(
                    0.0D,
                    0.0D,
                    0.25D,
                    1.0D,
                    1.0D,
                    1.0D
            );

    private static final VoxelShape CEILING_SHAPE =
            Shapes.box(
                    0.0D,
                    0.0D,
                    0.0D,
                    1.0D,
                    1.0D,
                    1.0D
            );

    public BeastSkullBlock(Properties properties) {
        super(properties);

        registerDefaultState(
                stateDefinition.any()
                        .setValue(
                                FACING,
                                Direction.NORTH
                        )
                        .setValue(
                                ROTATION,
                                0
                        )
                        .setValue(
                                PLACEMENT,
                                BeastSkullPlacement.FLOOR
                        )
        );
    }

    @Override
    protected MapCodec<? extends BaseEntityBlock> codec() {
        return CODEC;
    }

    @Override
    protected void createBlockStateDefinition(
            StateDefinition.Builder<
                    net.minecraft.world.level.block.Block,
                    BlockState
                    > builder
    ) {
        builder.add(
                FACING,
                ROTATION,
                PLACEMENT
        );
    }

    @Override
    public RenderShape getRenderShape(BlockState state) {
        return RenderShape.INVISIBLE;
    }

    @Nullable
    @Override
    public BlockEntity newBlockEntity(
            BlockPos pos,
            BlockState state
    ) {
        return new BeastSkullBlockEntity(pos, state);
    }

    @Nullable
    @Override
    public <T extends BlockEntity>
    BlockEntityTicker<T> getTicker(
            Level level,
            BlockState state,
            BlockEntityType<T> type
    ) {
        return createTickerHelper(
                type,
                net.droingo.decor.registry
                        .DecorBlockEntities
                        .BEAST_SKULL
                        .get(),
                BeastSkullBlockEntity::serverTick
        );
    }

    @Override
    protected VoxelShape getShape(
            BlockState state,
            BlockGetter level,
            BlockPos pos,
            CollisionContext context
    ) {
        return switch (
                state.getValue(PLACEMENT)
        ) {
            case FLOOR -> FLOOR_SHAPE;
            case WALL -> WALL_SHAPE;
            case CEILING -> CEILING_SHAPE;
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
    protected boolean canSurvive(
            BlockState state,
            LevelReader level,
            BlockPos pos
    ) {
        return switch (
                state.getValue(PLACEMENT)
        ) {
            case FLOOR ->
                    sturdy(
                            level,
                            pos.below(),
                            Direction.UP
                    );

            case CEILING ->
                    sturdy(
                            level,
                            pos.above(),
                            Direction.DOWN
                    );

            case WALL -> {
                Direction outward =
                        state.getValue(FACING);

                Direction supportDirection =
                        outward.getOpposite();

                yield sturdy(
                        level,
                        pos.relative(supportDirection),
                        outward
                );
            }
        };
    }

    private static boolean sturdy(
            LevelReader level,
            BlockPos supportPos,
            Direction face
    ) {
        return level.getBlockState(supportPos)
                .isFaceSturdy(
                        level,
                        supportPos,
                        face,
                        SupportType.CENTER
                );
    }

    @Override
    protected InteractionResult useWithoutItem(
            BlockState state,
            Level level,
            BlockPos pos,
            Player player,
            BlockHitResult hit
    ) {
        BeastSkullPlacement placement =
                state.getValue(PLACEMENT);

        if (player.isShiftKeyDown()) {
            if (placement == BeastSkullPlacement.WALL) {
                return InteractionResult.PASS;
            }

            if (!level.isClientSide) {
                level.setBlock(
                        pos,
                        state.cycle(ROTATION),
                        3
                );
            }

            return InteractionResult.sidedSuccess(
                    level.isClientSide
            );
        }

        if (
                !(level.getBlockEntity(pos)
                        instanceof BeastSkullBlockEntity skull)
        ) {
            return InteractionResult.PASS;
        }

        if (placement != BeastSkullPlacement.FLOOR) {
            if (!level.isClientSide) {
                skull.triggerSnap();
            }

            return InteractionResult.sidedSuccess(
                    level.isClientSide
            );
        }

        if (
                !level.isClientSide
                        && level
                        instanceof net.minecraft.server.level
                        .ServerLevel server
        ) {
            BeastSkullSeatEntity seat =
                    skull.findSeat(server);

            if (seat != null && seat.isVehicle()) {
                return InteractionResult.CONSUME;
            }

            if (seat == null) {
                seat = new BeastSkullSeatEntity(
                        DecorEntities.BEAST_SKULL_SEAT.get(),
                        level
                );

                seat.setParent(
                        pos,
                        state.getValue(FACING)
                );

                seat.moveTo(
                        pos.getX() + 0.5D,
                        pos.getY() + 0.66D,
                        pos.getZ() + 0.5D,
                        state.getValue(FACING).toYRot(),
                        0.0F
                );

                level.addFreshEntity(seat);
            }

            if (player.startRiding(seat, true)) {
                skull.beginChewing();
            }
        }

        return InteractionResult.sidedSuccess(
                level.isClientSide
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

        if (level.isClientSide) {
            return;
        }

        if (
                level.getBlockEntity(pos)
                        instanceof BeastSkullBlockEntity skull
        ) {
            skull.ejectAndRemoveSeat();
        }

        if (!player.getAbilities().instabuild) {
            ItemStack stack =
                    DecorItems.THE_BEAST_SKULL
                            .get()
                            .getDefaultInstance();

            if (!player.getInventory().add(stack)) {
                popResource(level, pos, stack);
            }
        }

        level.removeBlock(pos, false);
    }

    @Override
    protected void onRemove(
            BlockState state,
            Level level,
            BlockPos pos,
            BlockState newState,
            boolean movedByPiston
    ) {
        if (
                !state.is(newState.getBlock())
                        && level.getBlockEntity(pos)
                        instanceof BeastSkullBlockEntity skull
        ) {
            skull.ejectAndRemoveSeat();
        }

        super.onRemove(
                state,
                level,
                pos,
                newState,
                movedByPiston
        );
    }

    @Override
    public PushReaction getPistonPushReaction(
            BlockState state
    ) {
        return PushReaction.DESTROY;
    }
}
'@

Write-Utf8NoBom "src/main/java/net/droingo/decor/client/render/BeastSkullRenderer.java" @'
package net.droingo.decor.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import dev.ryanhcode.sable.Sable;
import net.droingo.decor.DroingosDecor;
import net.droingo.decor.client.animation.BeastSkullJawMotionState;
import net.droingo.decor.content.BeastSkullBlock;
import net.droingo.decor.content.BeastSkullBlockEntity;
import net.droingo.decor.content.BeastSkullPlacement;
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

import java.util.Map;
import java.util.WeakHashMap;

public final class BeastSkullRenderer
        implements BlockEntityRenderer<BeastSkullBlockEntity> {

    private final Map<
            BeastSkullBlockEntity,
            BeastSkullJawMotionState
            > motionStates = new WeakHashMap<>();

    public BeastSkullRenderer(
            BlockEntityRendererProvider.Context context
    ) {
    }

    @Override
    public void render(
            BeastSkullBlockEntity be,
            float partialTick,
            PoseStack pose,
            MultiBufferSource buffers,
            int light,
            int overlay
    ) {
        BeastSkullPlacement placement =
                be.getBlockState()
                        .getValue(
                                BeastSkullBlock.PLACEMENT
                        );

        String variant =
                placement.getSerializedName();

        float yaw =
                yawDegrees(be);

        BeastSkullJawMotionState motion =
                motionStates.computeIfAbsent(
                        be,
                        ignored ->
                                new BeastSkullJawMotionState()
                );

        updateMotion(
                be,
                motion,
                yaw
        );

        pose.pushPose();

        pose.translate(
                0.5D,
                0.0D,
                0.5D
        );

        pose.mulPose(
                Axis.YP.rotationDegrees(yaw)
        );

        pose.translate(
                -0.5D,
                0.0D,
                -0.5D
        );

        renderModel(
                model(
                        "the_beast_"
                                + variant
                                + "_static"
                ),
                pose,
                buffers,
                light,
                overlay
        );

        JawPivot pivot =
                jawPivot(placement);

        pose.pushPose();

        pose.translate(
                pivot.x(),
                pivot.y(),
                pivot.z()
        );

        pose.mulPose(
                Axis.XP.rotationDegrees(
                        jawAngle(
                                be,
                                partialTick
                        )
                                + motion.getAngle()
                )
        );

        pose.translate(
                -pivot.x(),
                -pivot.y(),
                -pivot.z()
        );

        renderModel(
                model(
                        "the_beast_"
                                + variant
                                + "_jaw"
                ),
                pose,
                buffers,
                light,
                overlay
        );

        pose.popPose();
        pose.popPose();
    }

    private static float yawDegrees(
            BeastSkullBlockEntity be
    ) {
        BeastSkullPlacement placement =
                be.getBlockState()
                        .getValue(
                                BeastSkullBlock.PLACEMENT
                        );

        if (placement == BeastSkullPlacement.WALL) {
            /*
             * The authored wall model points opposite Minecraft's outward
             * support-face direction, so flip it by 180 degrees.
             */
            Direction outward =
                    be.getBlockState()
                            .getValue(
                                    BeastSkullBlock.FACING
                            );

            return outward.toYRot() + 180.0F;
        }

        return be.getBlockState()
                .getValue(
                        BeastSkullBlock.ROTATION
                ) * 22.5F;
    }

    private static JawPivot jawPivot(
            BeastSkullPlacement placement
    ) {
        return switch (placement) {
            case FLOOR ->
                    new JawPivot(
                            8.0D / 16.0D,
                            19.75D / 16.0D,
                            11.0D / 16.0D
                    );

            case WALL ->
                    new JawPivot(
                            8.0D / 16.0D,
                            10.75D / 16.0D,
                            5.0D / 16.0D
                    );

            case CEILING ->
                    new JawPivot(
                            8.0D / 16.0D,
                            2.75D / 16.0D,
                            15.0D / 16.0D
                    );
        };
    }

    private static void updateMotion(
            BeastSkullBlockEntity be,
            BeastSkullJawMotionState motion,
            float yaw
    ) {
        Level level = be.getLevel();

        if (level == null) {
            return;
        }

        double now =
                System.nanoTime() * 1.0E-9D;

        JawPivot pivot =
                jawPivot(
                        be.getBlockState()
                                .getValue(
                                        BeastSkullBlock.PLACEMENT
                                )
                );

        Vec3 localOrigin =
                new Vec3(
                        be.getBlockPos().getX()
                                + pivot.x(),
                        be.getBlockPos().getY()
                                + pivot.y(),
                        be.getBlockPos().getZ()
                                + pivot.z()
                );

        Vec3 worldOrigin =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin
                );

        Vec3 worldX =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin.add(
                                1.0D,
                                0.0D,
                                0.0D
                        )
                ).subtract(worldOrigin);

        Vec3 worldZ =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin.add(
                                0.0D,
                                0.0D,
                                1.0D
                        )
                ).subtract(worldOrigin);

        if (
                worldX.lengthSqr() < 0.000001D
                        || worldZ.lengthSqr()
                        < 0.000001D
        ) {
            return;
        }

        worldX = worldX.normalize();
        worldZ = worldZ.normalize();

        double radians =
                Math.toRadians(yaw);

        double cos =
                Math.cos(radians);

        double sin =
                Math.sin(radians);

        Vec3 localForward =
                worldX.scale(sin)
                        .add(
                                worldZ.scale(cos)
                        )
                        .normalize();

        motion.update(
                now,
                worldOrigin,
                localForward
        );
    }

    private static float jawAngle(
            BeastSkullBlockEntity be,
            float partialTick
    ) {
        if (
                be.getLevel() == null
                        || be.animationStart()
                        == Long.MIN_VALUE
        ) {
            return 0.0F;
        }

        float t =
                be.getLevel().getGameTime()
                        + partialTick
                        - be.animationStart();

        return switch (be.animation()) {
            case BeastSkullBlockEntity.ANIMATION_SNAP -> {
                if (t < 8.0F) {
                    yield ease(t / 8.0F) * 42.0F;
                }

                if (t < 13.0F) {
                    yield 42.0F;
                }

                if (t < 24.0F) {
                    yield (
                            1.0F
                                    - ease(
                                    (t - 13.0F)
                                            / 11.0F
                            )
                    ) * 42.0F;
                }

                yield 0.0F;
            }

            case BeastSkullBlockEntity.ANIMATION_CHEW -> {
                float phase =
                        (t % 24.0F)
                                / 24.0F;

                yield 12.0F
                        + (
                        0.5F
                                - 0.5F
                                * (float) Math.cos(
                                phase
                                        * Math.PI
                                        * 2.0D
                        )
                ) * 24.0F;
            }

            case BeastSkullBlockEntity.ANIMATION_HARD_BITE ->
                    t < 5.0F
                            ? (
                            1.0F
                                    - ease(t / 5.0F)
                    ) * 35.0F
                            : 0.0F;

            default -> 0.0F;
        };
    }

    private static float ease(float value) {
        float x =
                Math.max(
                        0.0F,
                        Math.min(
                                1.0F,
                                value
                        )
                );

        return x
                * x
                * (
                3.0F
                        - 2.0F
                        * x
        );
    }

    private static ResourceLocation model(
            String name
    ) {
        return ResourceLocation.fromNamespaceAndPath(
                DroingosDecor.MOD_ID,
                "block/" + name
        );
    }

    private static void renderModel(
            ResourceLocation location,
            PoseStack pose,
            MultiBufferSource buffers,
            int light,
            int overlay
    ) {
        Minecraft minecraft =
                Minecraft.getInstance();

        BakedModel baked =
                minecraft
                        .getModelManager()
                        .getModel(
                                ModelResourceLocation
                                        .standalone(
                                                location
                                        )
                        );

        BlockRenderDispatcher dispatcher =
                minecraft.getBlockRenderer();

        dispatcher.getModelRenderer()
                .renderModel(
                        pose.last(),
                        buffers.getBuffer(
                                RenderType.cutout()
                        ),
                        Blocks.AIR
                                .defaultBlockState(),
                        baked,
                        1.0F,
                        1.0F,
                        1.0F,
                        light,
                        overlay,
                        ModelData.EMPTY,
                        RenderType.cutout()
                );
    }

    @Override
    public boolean shouldRenderOffScreen(
            BeastSkullBlockEntity blockEntity
    ) {
        return true;
    }

    private record JawPivot(
            double x,
            double y,
            double z
    ) {
    }
}
'@

Write-Host ""
Write-Host "Updated Beast Skull rotation, wall facing, and jaw inertia."
Write-Host "Building..."
Write-Host ""

& ".\gradlew.bat" build

if ($LASTEXITCODE -ne 0) {
    throw "Build failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Build successful."
