$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Root = (Get-Location).Path
$BackupRoot = Join-Path $Root (".ceiling_plant_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))

function Backup-File {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $Target = Join-Path $Root $RelativePath

    if (Test-Path -LiteralPath $Target) {
        $Backup = Join-Path $BackupRoot $RelativePath
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Backup) | Out-Null
        Copy-Item -LiteralPath $Target -Destination $Backup -Force
    }
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Content
    )

    Backup-File $RelativePath

    $Target = Join-Path $Root $RelativePath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Target) | Out-Null
    [System.IO.File]::WriteAllText($Target, $Content, $Utf8NoBom)
}

if (!(Test-Path -LiteralPath (Join-Path $Root "build.gradle"))) {
    throw "Run this script from the Droingo's Decor project root."
}

# ---------------------------------------------------------------------------
# Ceiling-only hanging plant block, item and block entity
# ---------------------------------------------------------------------------

Write-Utf8NoBom `
    "src/main/java/net/droingo/decor/content/CeilingPlantBlock.java" `
@'
package net.droingo.decor.content;

import com.mojang.serialization.MapCodec;
import net.droingo.decor.registry.DecorItems;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.BaseEntityBlock;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.SupportType;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.block.state.properties.IntegerProperty;
import net.minecraft.world.level.material.PushReaction;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;
import org.jetbrains.annotations.Nullable;

public final class CeilingPlantBlock extends BaseEntityBlock {
    public static final MapCodec<CeilingPlantBlock> CODEC =
            simpleCodec(CeilingPlantBlock::new);

    public static final IntegerProperty ROTATION =
            BlockStateProperties.ROTATION_16;

    private static final VoxelShape POT_SHAPE =
            Shapes.box(
                    5.5D / 16.0D,
                    7.0D / 16.0D,
                    5.5D / 16.0D,
                    10.5D / 16.0D,
                    1.0D,
                    10.5D / 16.0D
            );

    public CeilingPlantBlock(Properties properties) {
        super(properties);

        registerDefaultState(
                stateDefinition.any()
                        .setValue(ROTATION, 0)
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
        builder.add(ROTATION);
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
        return new CeilingPlantBlockEntity(pos, state);
    }

    @Override
    protected VoxelShape getShape(
            BlockState state,
            BlockGetter level,
            BlockPos pos,
            CollisionContext context
    ) {
        return POT_SHAPE;
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
            net.minecraft.world.level.LevelReader level,
            BlockPos pos
    ) {
        BlockPos supportPos = pos.above();

        return level.getBlockState(supportPos)
                .isFaceSturdy(
                        level,
                        supportPos,
                        Direction.DOWN,
                        SupportType.CENTER
                );
    }

    @Override
    protected BlockState updateShape(
            BlockState state,
            Direction direction,
            BlockState neighbourState,
            net.minecraft.world.level.LevelAccessor level,
            BlockPos pos,
            BlockPos neighbourPos
    ) {
        if (
                direction == Direction.UP
                        && !state.canSurvive(level, pos)
        ) {
            return net.minecraft.world.level.block.Blocks.AIR
                    .defaultBlockState();
        }

        return super.updateShape(
                state,
                direction,
                neighbourState,
                level,
                pos,
                neighbourPos
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
        /*
         * There is deliberately no normal right-click interaction.
         * Sneak-right-click keeps the mod's standard decor rotation control.
         */
        if (!player.isShiftKeyDown()) {
            return InteractionResult.PASS;
        }

        if (!level.isClientSide) {
            level.setBlock(
                    pos,
                    state.cycle(ROTATION),
                    3
            );
        }

        return InteractionResult.sidedSuccess(level.isClientSide);
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

        if (!player.getAbilities().instabuild) {
            ItemStack stack =
                    DecorItems.POTTED_PLANT_CEILING
                            .get()
                            .getDefaultInstance();

            if (!player.getInventory().add(stack)) {
                popResource(level, pos, stack);
            }
        }

        level.removeBlock(pos, false);
    }

    @Override
    protected PushReaction getPistonPushReaction(
            BlockState state
    ) {
        return PushReaction.DESTROY;
    }
}
'@

Write-Utf8NoBom `
    "src/main/java/net/droingo/decor/content/CeilingPlantBlockEntity.java" `
@'
package net.droingo.decor.content;

import net.droingo.decor.registry.DecorBlockEntities;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;

public final class CeilingPlantBlockEntity extends BlockEntity {
    public CeilingPlantBlockEntity(
            BlockPos pos,
            BlockState state
    ) {
        super(
                DecorBlockEntities.CEILING_PLANT.get(),
                pos,
                state
        );
    }
}
'@

Write-Utf8NoBom `
    "src/main/java/net/droingo/decor/content/CeilingPlantItem.java" `
@'
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

public final class CeilingPlantItem extends Item {
    public CeilingPlantItem(Properties properties) {
        super(properties);
    }

    @Override
    public InteractionResult useOn(UseOnContext context) {
        if (context.getClickedFace() != Direction.DOWN) {
            return InteractionResult.FAIL;
        }

        Level level = context.getLevel();
        BlockPos pos = context.getClickedPos().below();

        if (!level.getBlockState(pos).canBeReplaced()) {
            return InteractionResult.FAIL;
        }

        int rotation =
                Mth.floor(
                        (context.getRotation() + 11.25F)
                                / 22.5F
                ) & 15;

        BlockState state =
                DecorBlocks.CEILING_PLANT
                        .get()
                        .defaultBlockState()
                        .setValue(
                                CeilingPlantBlock.ROTATION,
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

# ---------------------------------------------------------------------------
# Main gravity pendulum
# ---------------------------------------------------------------------------

Write-Utf8NoBom `
    "src/main/java/net/droingo/decor/client/animation/CeilingPendulumMotionState.java" `
@'
package net.droingo.decor.client.animation;

import net.minecraft.util.Mth;
import net.minecraft.world.phys.Vec3;

import java.util.Arrays;

public final class CeilingPendulumMotionState {
    private static final float MAX_ANGLE = 78.0F;
    private static final float SPRING = 0.20F;
    private static final float DAMPING = 0.88F;
    private static final float MAX_SPEED = 12.0F;

    private static final double INERTIA = 3.2D;
    private static final double DEAD_ZONE = 0.00175D;
    private static final double MAX_SAMPLE_SPEED = 8.0D;
    private static final double MAX_ACCELERATION = 1.5D;

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

    private final Vec3[] velocitySamples =
            new Vec3[FILTER_SIZE];

    private int sampleCount;
    private int sampleIndex;

    private float targetPitch;
    private float targetRoll;

    private float pitch;
    private float roll;

    private float pitchVelocity;
    private float rollVelocity;

    public void update(
            double seconds,
            Vec3 worldPosition,
            Vec3 localRight,
            Vec3 localUp,
            Vec3 localForward
    ) {
        if (
                !Double.isFinite(seconds)
                        || !finite(worldPosition)
        ) {
            return;
        }

        if (!initialized) {
            reset(seconds, worldPosition);
            updateTargets(
                    localRight,
                    localUp,
                    localForward
            );
            pitch = targetPitch;
            roll = targetRoll;
            return;
        }

        double frameSeconds =
                seconds - lastRenderSeconds;

        if (
                frameSeconds <= 0.0D
                        || frameSeconds
                        > MAX_RENDER_GAP_SECONDS
        ) {
            reset(seconds, worldPosition);
            updateTargets(
                    localRight,
                    localUp,
                    localForward
            );
            pitch = targetPitch;
            roll = targetRoll;
            return;
        }

        Vec3 delta =
                worldPosition.subtract(lastPosition);

        if (
                delta.lengthSqr()
                        > POSITION_EPSILON_SQR
        ) {
            double sampleSeconds =
                    seconds - lastMotionSampleSeconds;

            if (
                    sampleSeconds > 0.0D
                            && sampleSeconds
                            <= MAX_SAMPLE_GAP_SECONDS
            ) {
                sampleMotion(
                        worldPosition,
                        sampleSeconds
                );
            } else {
                clearFilter();
                lastFilteredVelocity = Vec3.ZERO;
                acceleration = Vec3.ZERO;
            }

            lastPosition = worldPosition;
            lastMotionSampleSeconds = seconds;
        } else {
            acceleration = acceleration.scale(
                    Math.pow(
                            0.72D,
                            frameSeconds * 20.0D
                    )
            );
        }

        updateTargets(
                localRight,
                localUp,
                localForward
        );

        integrate(
                (float) (frameSeconds * 20.0D)
        );

        lastRenderSeconds = seconds;
    }

    private void sampleMotion(
            Vec3 worldPosition,
            double sampleSeconds
    ) {
        double sampleTicks =
                sampleSeconds * 20.0D;

        if (sampleTicks <= 0.0001D) {
            return;
        }

        Vec3 velocity = worldPosition
                .subtract(lastPosition)
                .scale(1.0D / sampleTicks);

        if (
                velocity.lengthSqr()
                        > MAX_SAMPLE_SPEED
                        * MAX_SAMPLE_SPEED
        ) {
            clearFilter();
            lastFilteredVelocity = Vec3.ZERO;
            acceleration = Vec3.ZERO;
            return;
        }

        addSample(velocity);

        Vec3 filtered =
                filteredVelocity();

        Vec3 newAcceleration = filtered
                .subtract(lastFilteredVelocity)
                .scale(1.0D / sampleTicks);

        double length =
                newAcceleration.length();

        if (length < DEAD_ZONE) {
            newAcceleration = Vec3.ZERO;
        } else if (length > MAX_ACCELERATION) {
            newAcceleration =
                    newAcceleration.scale(
                            MAX_ACCELERATION / length
                    );
        }

        acceleration = newAcceleration;
        lastFilteredVelocity = filtered;
    }

    private void updateTargets(
            Vec3 localRight,
            Vec3 localUp,
            Vec3 localForward
    ) {
        /*
         * Gravity minus vehicle acceleration gives the apparent down
         * direction seen by a freely hanging object.
         */
        Vec3 apparentDown =
                new Vec3(0.0D, -1.0D, 0.0D)
                        .subtract(
                                acceleration.scale(INERTIA)
                        );

        if (
                apparentDown.lengthSqr()
                        < 0.000001D
        ) {
            apparentDown =
                    new Vec3(0.0D, -1.0D, 0.0D);
        } else {
            apparentDown = apparentDown.normalize();
        }

        double down =
                apparentDown.dot(
                        localUp.scale(-1.0D)
                );

        double right =
                apparentDown.dot(localRight);

        double forward =
                apparentDown.dot(localForward);

        targetPitch = Mth.clamp(
                (float) Math.toDegrees(
                        Math.atan2(
                                -forward,
                                down
                        )
                ),
                -MAX_ANGLE,
                MAX_ANGLE
        );

        targetRoll = Mth.clamp(
                (float) Math.toDegrees(
                        Math.atan2(
                                right,
                                down
                        )
                ),
                -MAX_ANGLE,
                MAX_ANGLE
        );
    }

    private void integrate(float ticks) {
        ticks = Mth.clamp(ticks, 0.0F, 2.0F);

        pitchVelocity +=
                (targetPitch - pitch)
                        * SPRING
                        * ticks;

        rollVelocity +=
                (targetRoll - roll)
                        * SPRING
                        * ticks;

        float damping =
                (float) Math.pow(DAMPING, ticks);

        pitchVelocity *= damping;
        rollVelocity *= damping;

        pitchVelocity = Mth.clamp(
                pitchVelocity,
                -MAX_SPEED,
                MAX_SPEED
        );

        rollVelocity = Mth.clamp(
                rollVelocity,
                -MAX_SPEED,
                MAX_SPEED
        );

        pitch += pitchVelocity * ticks;
        roll += rollVelocity * ticks;

        pitch = Mth.clamp(
                pitch,
                -MAX_ANGLE,
                MAX_ANGLE
        );

        roll = Mth.clamp(
                roll,
                -MAX_ANGLE,
                MAX_ANGLE
        );
    }

    private void addSample(Vec3 velocity) {
        velocitySamples[sampleIndex] = velocity;

        sampleIndex =
                (sampleIndex + 1) % FILTER_SIZE;

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

            for (
                    int index = 0;
                    index < sampleCount;
                    index++
            ) {
                total = total.add(
                        velocitySamples[index]
                );
            }

            return total.scale(
                    1.0D / sampleCount
            );
        }

        double[] x = new double[FILTER_SIZE];
        double[] y = new double[FILTER_SIZE];
        double[] z = new double[FILTER_SIZE];

        for (
                int index = 0;
                index < FILTER_SIZE;
                index++
        ) {
            Vec3 sample =
                    velocitySamples[index];

            x[index] = sample.x;
            y[index] = sample.y;
            z[index] = sample.z;
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
        Arrays.fill(
                velocitySamples,
                Vec3.ZERO
        );

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
        clearFilter();
        pitchVelocity = 0.0F;
        rollVelocity = 0.0F;
    }

    private static boolean finite(Vec3 value) {
        return Double.isFinite(value.x)
                && Double.isFinite(value.y)
                && Double.isFinite(value.z);
    }

    public float getPitch() {
        return pitch;
    }

    public float getRoll() {
        return roll;
    }
}
'@

# ---------------------------------------------------------------------------
# Three-bone trailing vine chain
# ---------------------------------------------------------------------------

Write-Utf8NoBom `
    "src/main/java/net/droingo/decor/client/animation/VineChainMotionState.java" `
@'
package net.droingo.decor.client.animation;

import net.minecraft.util.Mth;

public final class VineChainMotionState {
    private static final int SEGMENTS = 3;

    private static final float[] FOLLOW = {
            0.42F,
            0.28F,
            0.18F
    };

    private static final float[] DAMPING = {
            0.82F,
            0.85F,
            0.88F
    };

    private static final float[] TRAIL = {
            0.28F,
            0.46F,
            0.66F
    };

    private static final float[] LIMIT = {
            18.0F,
            26.0F,
            34.0F
    };

    private final float[] pitch =
            new float[SEGMENTS];

    private final float[] roll =
            new float[SEGMENTS];

    private final float[] pitchVelocity =
            new float[SEGMENTS];

    private final float[] rollVelocity =
            new float[SEGMENTS];

    private float previousRootPitch;
    private float previousRootRoll;

    public void update(
            float rootPitch,
            float rootRoll,
            float deltaTicks
    ) {
        deltaTicks = Mth.clamp(
                deltaTicks,
                0.0F,
                2.0F
        );

        float rootPitchDelta =
                rootPitch - previousRootPitch;

        float rootRollDelta =
                rootRoll - previousRootRoll;

        float parentPitchDelta =
                rootPitchDelta;

        float parentRollDelta =
                rootRollDelta;

        for (int index = 0; index < SEGMENTS; index++) {
            float targetPitch =
                    -parentPitchDelta
                            * TRAIL[index]
                            * 7.0F;

            float targetRoll =
                    -parentRollDelta
                            * TRAIL[index]
                            * 7.0F;

            pitchVelocity[index] +=
                    (targetPitch - pitch[index])
                            * FOLLOW[index]
                            * deltaTicks;

            rollVelocity[index] +=
                    (targetRoll - roll[index])
                            * FOLLOW[index]
                            * deltaTicks;

            float damping =
                    (float) Math.pow(
                            DAMPING[index],
                            deltaTicks
                    );

            pitchVelocity[index] *= damping;
            rollVelocity[index] *= damping;

            pitch[index] +=
                    pitchVelocity[index]
                            * deltaTicks;

            roll[index] +=
                    rollVelocity[index]
                            * deltaTicks;

            pitch[index] = Mth.clamp(
                    pitch[index],
                    -LIMIT[index],
                    LIMIT[index]
            );

            roll[index] = Mth.clamp(
                    roll[index],
                    -LIMIT[index],
                    LIMIT[index]
            );

            parentPitchDelta =
                    pitchVelocity[index]
                            * deltaTicks;

            parentRollDelta =
                    rollVelocity[index]
                            * deltaTicks;
        }

        previousRootPitch = rootPitch;
        previousRootRoll = rootRoll;
    }

    public float getPitch(int segment) {
        return pitch[segment];
    }

    public float getRoll(int segment) {
        return roll[segment];
    }
}
'@

# ---------------------------------------------------------------------------
# Renderer
# ---------------------------------------------------------------------------

Write-Utf8NoBom `
    "src/main/java/net/droingo/decor/client/render/CeilingPlantRenderer.java" `
@'
package net.droingo.decor.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;
import dev.ryanhcode.sable.Sable;
import net.droingo.decor.DroingosDecor;
import net.droingo.decor.client.animation.CeilingPendulumMotionState;
import net.droingo.decor.client.animation.VineChainMotionState;
import net.droingo.decor.content.CeilingPlantBlock;
import net.droingo.decor.content.CeilingPlantBlockEntity;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.block.BlockRenderDispatcher;
import net.minecraft.client.renderer.blockentity.BlockEntityRenderer;
import net.minecraft.client.renderer.blockentity.BlockEntityRendererProvider;
import net.minecraft.client.resources.model.BakedModel;
import net.minecraft.client.resources.model.ModelResourceLocation;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.phys.Vec3;
import net.neoforged.neoforge.client.model.data.ModelData;

import java.util.Map;
import java.util.WeakHashMap;

public final class CeilingPlantRenderer
        implements BlockEntityRenderer<CeilingPlantBlockEntity> {

    private static final ResourceLocation POT_VINE_0 =
            model("potted_plant_ceiling_pot_vine0");

    private static final ResourceLocation VINE_1 =
            model("potted_plant_ceiling_vine1");

    private static final ResourceLocation VINE_2 =
            model("potted_plant_ceiling_vine2");

    private static final ResourceLocation VINE_3 =
            model("potted_plant_ceiling_vine3");

    private static final double ROOT_X = 8.0D / 16.0D;
    private static final double ROOT_Y = 16.0D / 16.0D;
    private static final double ROOT_Z = 8.0D / 16.0D;

    private static final double[][] VINE_PIVOTS = {
            {
                    12.0D / 16.0D,
                    10.0D / 16.0D,
                    8.0D / 16.0D
            },
            {
                    12.0D / 16.0D,
                    6.1D / 16.0D,
                    7.9D / 16.0D
            },
            {
                    12.0D / 16.0D,
                    1.1D / 16.0D,
                    8.0D / 16.0D
            }
    };

    private final Map<
            CeilingPlantBlockEntity,
            PlantMotion
            > motionStates = new WeakHashMap<>();

    private final BlockRenderDispatcher blockRenderer;

    public CeilingPlantRenderer(
            BlockEntityRendererProvider.Context context
    ) {
        blockRenderer =
                context.getBlockRenderDispatcher();
    }

    @Override
    public void render(
            CeilingPlantBlockEntity blockEntity,
            float partialTick,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        PlantMotion motion =
                motionStates.computeIfAbsent(
                        blockEntity,
                        ignored -> new PlantMotion()
                );

        float frameTicks = updateMotion(
                blockEntity,
                motion
        );

        motion.vines.update(
                motion.root.getPitch(),
                motion.root.getRoll(),
                frameTicks
        );

        float yaw =
                blockEntity.getBlockState()
                        .getValue(
                                CeilingPlantBlock.ROTATION
                        )
                        * 22.5F;

        poseStack.pushPose();

        /*
         * Authored yaw rotation around the block centre.
         */
        poseStack.translate(0.5D, 0.5D, 0.5D);
        poseStack.mulPose(
                Axis.YP.rotationDegrees(yaw)
        );
        poseStack.translate(-0.5D, -0.5D, -0.5D);

        /*
         * Whole plant swings from the ceiling attachment.
         */
        poseStack.translate(
                ROOT_X,
                ROOT_Y,
                ROOT_Z
        );

        poseStack.mulPose(
                Axis.XP.rotationDegrees(
                        motion.root.getPitch()
                )
        );

        poseStack.mulPose(
                Axis.ZP.rotationDegrees(
                        motion.root.getRoll()
                )
        );

        poseStack.translate(
                -ROOT_X,
                -ROOT_Y,
                -ROOT_Z
        );

        renderModel(
                poseStack,
                buffers,
                POT_VINE_0,
                packedLight,
                packedOverlay
        );

        renderVineChain(
                poseStack,
                buffers,
                motion,
                packedLight,
                packedOverlay
        );

        poseStack.popPose();
    }

    private float updateMotion(
            CeilingPlantBlockEntity blockEntity,
            PlantMotion motion
    ) {
        Level level = blockEntity.getLevel();

        if (level == null) {
            return 0.0F;
        }

        double now =
                System.nanoTime() * 1.0E-9D;

        float frameTicks;

        if (
                motion.lastRenderSeconds == 0.0D
                        || now <= motion.lastRenderSeconds
        ) {
            frameTicks = 0.0F;
        } else {
            frameTicks = (float) Math.min(
                    2.0D,
                    (now - motion.lastRenderSeconds)
                            * 20.0D
            );
        }

        motion.lastRenderSeconds = now;

        Vec3 localOrigin = new Vec3(
                blockEntity.getBlockPos().getX()
                        + ROOT_X,
                blockEntity.getBlockPos().getY()
                        + ROOT_Y,
                blockEntity.getBlockPos().getZ()
                        + ROOT_Z
        );

        Vec3 worldOrigin =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin
                );

        Vec3 worldX =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin.add(1.0D, 0.0D, 0.0D)
                ).subtract(worldOrigin);

        Vec3 worldY =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin.add(0.0D, 1.0D, 0.0D)
                ).subtract(worldOrigin);

        Vec3 worldZ =
                Sable.HELPER.projectOutOfSubLevel(
                        level,
                        localOrigin.add(0.0D, 0.0D, 1.0D)
                ).subtract(worldOrigin);

        if (
                worldX.lengthSqr() < 0.000001D
                        || worldY.lengthSqr()
                        < 0.000001D
                        || worldZ.lengthSqr()
                        < 0.000001D
        ) {
            return frameTicks;
        }

        double yawRadians = Math.toRadians(
                blockEntity.getBlockState()
                        .getValue(
                                CeilingPlantBlock.ROTATION
                        )
                        * 22.5D
        );

        double cos = Math.cos(yawRadians);
        double sin = Math.sin(yawRadians);

        worldX = worldX.normalize();
        worldY = worldY.normalize();
        worldZ = worldZ.normalize();

        Vec3 localRight =
                worldX.scale(cos)
                        .add(
                                worldZ.scale(-sin)
                        )
                        .normalize();

        Vec3 localForward =
                worldX.scale(sin)
                        .add(
                                worldZ.scale(cos)
                        )
                        .normalize();

        motion.root.update(
                now,
                worldOrigin,
                localRight,
                worldY,
                localForward
        );

        return frameTicks;
    }

    private void renderVineChain(
            PoseStack poseStack,
            MultiBufferSource buffers,
            PlantMotion motion,
            int packedLight,
            int packedOverlay
    ) {
        ResourceLocation[] models = {
                VINE_1,
                VINE_2,
                VINE_3
        };

        poseStack.pushPose();

        for (int index = 0; index < 3; index++) {
            double[] pivot =
                    VINE_PIVOTS[index];

            poseStack.translate(
                    pivot[0],
                    pivot[1],
                    pivot[2]
            );

            poseStack.mulPose(
                    Axis.XP.rotationDegrees(
                            motion.vines.getPitch(index)
                    )
            );

            poseStack.mulPose(
                    Axis.ZP.rotationDegrees(
                            motion.vines.getRoll(index)
                    )
            );

            poseStack.translate(
                    -pivot[0],
                    -pivot[1],
                    -pivot[2]
            );

            renderModel(
                    poseStack,
                    buffers,
                    models[index],
                    packedLight,
                    packedOverlay
            );
        }

        poseStack.popPose();
    }

    private void renderModel(
            PoseStack poseStack,
            MultiBufferSource buffers,
            ResourceLocation location,
            int light,
            int overlay
    ) {
        BakedModel model =
                Minecraft.getInstance()
                        .getModelManager()
                        .getModel(
                                ModelResourceLocation.standalone(
                                        location
                                )
                        );

        VertexConsumer consumer =
                buffers.getBuffer(
                        RenderType.cutout()
                );

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

    @Override
    public boolean shouldRenderOffScreen(
            CeilingPlantBlockEntity blockEntity
    ) {
        return true;
    }

    private static ResourceLocation model(String name) {
        return ResourceLocation.fromNamespaceAndPath(
                DroingosDecor.MOD_ID,
                "block/" + name
        );
    }

    private static final class PlantMotion {
        private final CeilingPendulumMotionState root =
                new CeilingPendulumMotionState();

        private final VineChainMotionState vines =
                new VineChainMotionState();

        private double lastRenderSeconds;
    }
}
'@

# ---------------------------------------------------------------------------
# Registries
# ---------------------------------------------------------------------------

$BlocksRelative = "src/main/java/net/droingo/decor/registry/DecorBlocks.java"
$BlocksPath = Join-Path $Root $BlocksRelative
Backup-File $BlocksRelative
$Blocks = [System.IO.File]::ReadAllText($BlocksPath)

if (!$Blocks.Contains("import net.droingo.decor.content.CeilingPlantBlock;")) {
    $Blocks = $Blocks.Replace(
            "import net.droingo.decor.content.DecorContainerBlock;",
            "import net.droingo.decor.content.CeilingPlantBlock;`r`nimport net.droingo.decor.content.DecorContainerBlock;"
    )
}

if (!$Blocks.Contains("CEILING_PLANT =")) {
    $Anchor = "    public static final DeferredBlock<DecorContainerBlock> DECOR_CONTAINER ="

    if (!$Blocks.Contains($Anchor)) {
        throw "Could not find DECOR_CONTAINER registration anchor."
    }

    $Registration = @'
    public static final DeferredBlock<CeilingPlantBlock> CEILING_PLANT =
            BLOCKS.registerBlock(
                    "ceiling_plant",
                    CeilingPlantBlock::new,
                    BlockBehaviour.Properties.of()
                            .mapColor(MapColor.PLANT)
                            .strength(0.2F)
                            .sound(SoundType.WOOD)
                            .noOcclusion()
                            .noCollission()
            );

'@

    $Blocks = $Blocks.Replace(
            $Anchor,
            $Registration + $Anchor
    )
}

[System.IO.File]::WriteAllText(
        $BlocksPath,
        $Blocks,
        $Utf8NoBom
)

$EntitiesRelative = "src/main/java/net/droingo/decor/registry/DecorBlockEntities.java"
$EntitiesPath = Join-Path $Root $EntitiesRelative
Backup-File $EntitiesRelative
$Entities = [System.IO.File]::ReadAllText($EntitiesPath)

if (!$Entities.Contains("import net.droingo.decor.content.CeilingPlantBlockEntity;")) {
    $Entities = $Entities.Replace(
            "import net.droingo.decor.content.DecorContainerBlockEntity;",
            "import net.droingo.decor.content.CeilingPlantBlockEntity;`r`nimport net.droingo.decor.content.DecorContainerBlockEntity;"
    )
}

if (!$Entities.Contains("CEILING_PLANT = TYPES.register")) {
    $Anchor = @'
    public static final DeferredHolder<
            BlockEntityType<?>,
            BlockEntityType<DecorContainerBlockEntity>
'@

    if (!$Entities.Contains($Anchor)) {
        throw "Could not find block entity registration anchor."
    }

    $Registration = @'
    public static final DeferredHolder<
            BlockEntityType<?>,
            BlockEntityType<CeilingPlantBlockEntity>
            > CEILING_PLANT = TYPES.register(
            "ceiling_plant",
            () -> BlockEntityType.Builder.of(
                    CeilingPlantBlockEntity::new,
                    DecorBlocks.CEILING_PLANT.get()
            ).build(null)
    );

'@

    $Entities = $Entities.Replace(
            $Anchor,
            $Registration + $Anchor
    )
}

[System.IO.File]::WriteAllText(
        $EntitiesPath,
        $Entities,
        $Utf8NoBom
)

$ItemsRelative = "src/main/java/net/droingo/decor/registry/DecorItems.java"
$ItemsPath = Join-Path $Root $ItemsRelative
Backup-File $ItemsRelative
$Items = [System.IO.File]::ReadAllText($ItemsPath)

if (!$Items.Contains("import net.droingo.decor.content.CeilingPlantItem;")) {
    $ImportAnchor = "import net.droingo.decor.content."

    $FirstImport = [regex]::Match(
            $Items,
            '(?m)^import net\.droingo\.decor\.content\.[^;]+;'
    )

    if (!$FirstImport.Success) {
        throw "Could not find a decor content import in DecorItems.java."
    }

    $Items = $Items.Insert(
            $FirstImport.Index,
            "import net.droingo.decor.content.CeilingPlantItem;`r`n"
    )
}

if (!$Items.Contains("POTTED_PLANT_CEILING")) {
    $Anchor = [regex]::Match(
            $Items,
            '(?m)^[ \t]*public static final DeferredItem<Item> [A-Z0-9_]+ = ITEMS\.register\('
    )

    if (!$Anchor.Success) {
        throw "Could not find an item registration anchor."
    }

    $Registration = @'
    public static final DeferredItem<Item> POTTED_PLANT_CEILING =
            ITEMS.register(
                    "potted_plant_ceiling",
                    () -> new CeilingPlantItem(
                            new Item.Properties()
                    )
            );

'@

    $Items = $Items.Insert(
            $Anchor.Index,
            $Registration
    )
}

[System.IO.File]::WriteAllText(
        $ItemsPath,
        $Items,
        $Utf8NoBom
)

# ---------------------------------------------------------------------------
# Add to the existing definition-driven creative tab
# ---------------------------------------------------------------------------

$DefinitionsRelative = "src/main/java/net/droingo/decor/registry/DecorDefinitionRegistry.java"
$DefinitionsPath = Join-Path $Root $DefinitionsRelative
Backup-File $DefinitionsRelative
$Definitions = [System.IO.File]::ReadAllText($DefinitionsPath)

if (!$Definitions.Contains('ResourceLocation ceilingPlantId = id("potted_plant_ceiling");')) {
    $Anchor = '        ResourceLocation sweaterId = id("hanging_sweater");'

    if (!$Definitions.Contains($Anchor)) {
        throw "Could not find hanging_sweater definition anchor."
    }

    $Registration = @'
        ResourceLocation ceilingPlantId =
                id("potted_plant_ceiling");

        register(
                DecorDefinition.builder(ceilingPlantId)
                        .category(DecorCategory.HANGING_DECOR)
                        .placement(DecorPlacementType.HANGING)
                        .item(
                                DecorItems.POTTED_PLANT_CEILING::get
                        )
                        .bounds(
                                -0.5D,
                                -0.125D,
                                -0.5D,
                                0.5D,
                                1.0D,
                                0.5D
                        )
                        .build()
        );

'@

    $Definitions = $Definitions.Replace(
            $Anchor,
            $Registration + $Anchor
    )
}

[System.IO.File]::WriteAllText(
        $DefinitionsPath,
        $Definitions,
        $Utf8NoBom
)

# ---------------------------------------------------------------------------
# Client renderer and model registrations
# ---------------------------------------------------------------------------

$ClientRelative = "src/main/java/net/droingo/decor/client/DroingosDecorClient.java"
$ClientPath = Join-Path $Root $ClientRelative
Backup-File $ClientRelative
$Client = [System.IO.File]::ReadAllText($ClientPath)

if (!$Client.Contains("import net.droingo.decor.client.render.CeilingPlantRenderer;")) {
    $Client = $Client.Replace(
            "import net.droingo.decor.client.render.DecorContainerRenderer;",
            "import net.droingo.decor.client.render.CeilingPlantRenderer;`r`nimport net.droingo.decor.client.render.DecorContainerRenderer;"
    )
}

if (!$Client.Contains("DecorBlockEntities.CEILING_PLANT.get()")) {
    $Anchor = @'
        event.registerBlockEntityRenderer(
                DecorBlockEntities.DECOR_CONTAINER.get(),
'@

    if (!$Client.Contains($Anchor)) {
        throw "Could not find renderer registration anchor."
    }

    $Registration = @'
        event.registerBlockEntityRenderer(
                DecorBlockEntities.CEILING_PLANT.get(),
                CeilingPlantRenderer::new
        );

'@

    $Client = $Client.Replace(
            $Anchor,
            $Registration + $Anchor
    )
}

if (!$Client.Contains('"block/potted_plant_ceiling_pot_vine0"')) {
    $MethodAnchor = @'
    public static void registerAdditionalModels(
            ModelEvent.RegisterAdditional event
    ) {
'@

    if (!$Client.Contains($MethodAnchor)) {
        throw "Could not find registerAdditionalModels method."
    }

    $Models = @'
    public static void registerAdditionalModels(
            ModelEvent.RegisterAdditional event
    ) {
        event.register(
                ModelResourceLocation.standalone(
                        net.minecraft.resources.ResourceLocation
                                .fromNamespaceAndPath(
                                        DroingosDecor.MOD_ID,
                                        "block/potted_plant_ceiling_pot_vine0"
                                )
                )
        );

        event.register(
                ModelResourceLocation.standalone(
                        net.minecraft.resources.ResourceLocation
                                .fromNamespaceAndPath(
                                        DroingosDecor.MOD_ID,
                                        "block/potted_plant_ceiling_vine1"
                                )
                )
        );

        event.register(
                ModelResourceLocation.standalone(
                        net.minecraft.resources.ResourceLocation
                                .fromNamespaceAndPath(
                                        DroingosDecor.MOD_ID,
                                        "block/potted_plant_ceiling_vine2"
                                )
                )
        );

        event.register(
                ModelResourceLocation.standalone(
                        net.minecraft.resources.ResourceLocation
                                .fromNamespaceAndPath(
                                        DroingosDecor.MOD_ID,
                                        "block/potted_plant_ceiling_vine3"
                                )
                )
        );

'@

    $Client = $Client.Replace(
            $MethodAnchor,
            $Models
    )
}

[System.IO.File]::WriteAllText(
        $ClientPath,
        $Client,
        $Utf8NoBom
)

# ---------------------------------------------------------------------------
# Models, texture, blockstate and language
# ---------------------------------------------------------------------------

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/block/potted_plant_ceiling_pot_vine0.json" `
@'
{
  "parent": "minecraft:block/block",
  "texture_size": [
    32,
    32
  ],
  "textures": {
    "0": "droingos_decor:block/potted_plant_ceiling",
    "particle": "droingos_decor:block/potted_plant_ceiling"
  },
  "elements": [
    {
      "from": [
        5.5,
        9.5,
        5.5
      ],
      "to": [
        10.5,
        11,
        10.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          8,
          16,
          8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            9,
            13.5,
            11.5,
            14.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            13.5,
            9,
            16,
            9.75
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            13.5,
            10,
            16,
            10.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            14,
            2.5,
            14.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            2.5,
            11.5,
            0,
            9
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            5,
            9,
            2.5,
            11.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        6,
        7.25,
        6
      ],
      "to": [
        10,
        9.75,
        10
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          8,
          16,
          8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            13,
            4,
            15,
            5.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            13,
            11,
            15,
            12.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            13,
            12.5,
            15,
            13.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            13.5,
            7.5,
            15.5,
            8.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            11,
            13.5,
            9,
            11.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            13,
            11.5,
            11,
            13.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.49289,
        11,
        7.97868
      ],
      "to": [
        11.49289,
        17,
        7.97868
      ],
      "rotation": {
        "angle": 45,
        "axis": "y",
        "origin": [
          8,
          16,
          8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            5,
            0,
            8.5,
            3
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            5,
            3,
            8.5,
            6
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            3.5,
            0,
            0,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            3.5,
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
        4.47868,
        11,
        8.00711
      ],
      "to": [
        11.47868,
        17,
        8.00711
      ],
      "rotation": {
        "angle": -45,
        "axis": "y",
        "origin": [
          8,
          16,
          8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            6,
            3.5,
            9
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            3.5,
            6,
            7,
            9
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            3.5,
            0,
            0,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            3.5,
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
        10.6799,
        8.2,
        5.48995
      ],
      "to": [
        10.6799,
        14.2,
        10.48995
      ],
      "rotation": {
        "angle": 22.5,
        "axis": "z",
        "origin": [
          6.6799,
          12.2,
          7.98995
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            8.5,
            2.5,
            11,
            5.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            7,
            8.5,
            9.5,
            11.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0,
            2.5,
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
            2.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        7.9799,
        11,
        4.48995
      ],
      "to": [
        7.9799,
        16,
        11.48995
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.9799,
          14,
          7.98995
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            2.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            7,
            6,
            10.5,
            8.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            2.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            8.5,
            0,
            12,
            2.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0,
            3.5,
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
            3.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.4799,
        10,
        7.98995
      ],
      "to": [
        14.4799,
        16,
        7.98995
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.9799,
          14,
          7.98995
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            5,
            3
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            3,
            5,
            6
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            5,
            0,
            0,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            5,
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

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/block/potted_plant_ceiling_vine1.json" `
@'
{
  "parent": "minecraft:block/block",
  "texture_size": [
    32,
    32
  ],
  "textures": {
    "0": "droingos_decor:block/potted_plant_ceiling",
    "particle": "droingos_decor:block/potted_plant_ceiling"
  },
  "elements": [
    {
      "from": [
        10,
        6,
        8
      ],
      "to": [
        14,
        11,
        8
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          12,
          10,
          8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            11.5,
            2,
            14
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            2.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            2,
            11.5,
            4,
            14
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            2.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            2,
            0,
            0,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            2,
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
        12,
        6,
        6
      ],
      "to": [
        12,
        11,
        10
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          12,
          10,
          8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            2.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            7,
            11.5,
            9,
            14
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            2.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            11.5,
            8.5,
            13.5,
            11
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0,
            2,
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
            2
          ],
          "texture": "#0"
        }
      }
    }
  ]
}
'@

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/block/potted_plant_ceiling_vine2.json" `
@'
{
  "parent": "minecraft:block/block",
  "texture_size": [
    32,
    32
  ],
  "textures": {
    "0": "droingos_decor:block/potted_plant_ceiling",
    "particle": "droingos_decor:block/potted_plant_ceiling"
  },
  "elements": [
    {
      "from": [
        9.9,
        1,
        7.9
      ],
      "to": [
        13.9,
        7,
        7.9
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          12,
          6.1,
          7.9
        ]
      },
      "faces": {
        "north": {
          "uv": [
            5,
            9,
            7,
            12
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            9.5,
            8.5,
            11.5,
            11.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            2,
            0,
            0,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            2,
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
        11.9,
        1,
        6
      ],
      "to": [
        11.9,
        7,
        10
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          12,
          6.1,
          7.9
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            10.5,
            5.5,
            12.5,
            8.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            11,
            2.5,
            13,
            5.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0,
            2,
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
            2
          ],
          "texture": "#0"
        }
      }
    }
  ]
}
'@

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/block/potted_plant_ceiling_vine3.json" `
@'
{
  "parent": "minecraft:block/block",
  "texture_size": [
    32,
    32
  ],
  "textures": {
    "0": "droingos_decor:block/potted_plant_ceiling",
    "particle": "droingos_decor:block/potted_plant_ceiling"
  },
  "elements": [
    {
      "from": [
        10,
        -2,
        8
      ],
      "to": [
        14,
        2,
        8
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          12,
          1.1,
          8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            12,
            0,
            14,
            2
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            4,
            12,
            6,
            14
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            2,
            0,
            0,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            2,
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
        12,
        -2,
        6.1
      ],
      "to": [
        12,
        2,
        10.1
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          12,
          1.1,
          8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            12.5,
            5.5,
            14.5,
            7.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            13,
            2,
            15,
            4
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0,
            2,
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
            2
          ],
          "texture": "#0"
        }
      }
    }
  ]
}
'@

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/potted_plant_ceiling.json" `
@'
{
  "parent": "minecraft:block/block",
  "texture_size": [
    32,
    32
  ],
  "textures": {
    "0": "droingos_decor:block/potted_plant_ceiling",
    "particle": "droingos_decor:block/potted_plant_ceiling"
  },
  "elements": [
    {
      "from": [
        5.5,
        9.5,
        5.5
      ],
      "to": [
        10.5,
        11,
        10.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          8,
          16,
          8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            9,
            13.5,
            11.5,
            14.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            13.5,
            9,
            16,
            9.75
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            13.5,
            10,
            16,
            10.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            14,
            2.5,
            14.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            2.5,
            11.5,
            0,
            9
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            5,
            9,
            2.5,
            11.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        6,
        7.25,
        6
      ],
      "to": [
        10,
        9.75,
        10
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          8,
          16,
          8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            13,
            4,
            15,
            5.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            13,
            11,
            15,
            12.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            13,
            12.5,
            15,
            13.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            13.5,
            7.5,
            15.5,
            8.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            11,
            13.5,
            9,
            11.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            13,
            11.5,
            11,
            13.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.49289,
        11,
        7.97868
      ],
      "to": [
        11.49289,
        17,
        7.97868
      ],
      "rotation": {
        "angle": 45,
        "axis": "y",
        "origin": [
          8,
          16,
          8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            5,
            0,
            8.5,
            3
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            5,
            3,
            8.5,
            6
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            3.5,
            0,
            0,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            3.5,
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
        4.47868,
        11,
        8.00711
      ],
      "to": [
        11.47868,
        17,
        8.00711
      ],
      "rotation": {
        "angle": -45,
        "axis": "y",
        "origin": [
          8,
          16,
          8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            6,
            3.5,
            9
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            3.5,
            6,
            7,
            9
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            3.5,
            0,
            0,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            3.5,
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
        10.6799,
        8.2,
        5.48995
      ],
      "to": [
        10.6799,
        14.2,
        10.48995
      ],
      "rotation": {
        "angle": 22.5,
        "axis": "z",
        "origin": [
          6.6799,
          12.2,
          7.98995
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            8.5,
            2.5,
            11,
            5.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            7,
            8.5,
            9.5,
            11.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0,
            2.5,
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
            2.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        7.9799,
        11,
        4.48995
      ],
      "to": [
        7.9799,
        16,
        11.48995
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.9799,
          14,
          7.98995
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            2.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            7,
            6,
            10.5,
            8.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            2.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            8.5,
            0,
            12,
            2.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0,
            3.5,
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
            3.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.4799,
        10,
        7.98995
      ],
      "to": [
        14.4799,
        16,
        7.98995
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.9799,
          14,
          7.98995
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            5,
            3
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            3,
            5,
            6
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            5,
            0,
            0,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            5,
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
        10,
        6,
        8
      ],
      "to": [
        14,
        11,
        8
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          12,
          10,
          8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            11.5,
            2,
            14
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            2.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            2,
            11.5,
            4,
            14
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            2.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            2,
            0,
            0,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            2,
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
        12,
        6,
        6
      ],
      "to": [
        12,
        11,
        10
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          12,
          10,
          8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            2.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            7,
            11.5,
            9,
            14
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            2.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            11.5,
            8.5,
            13.5,
            11
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0,
            2,
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
            2
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        9.9,
        1,
        7.9
      ],
      "to": [
        13.9,
        7,
        7.9
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          12,
          6.1,
          7.9
        ]
      },
      "faces": {
        "north": {
          "uv": [
            5,
            9,
            7,
            12
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            9.5,
            8.5,
            11.5,
            11.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            2,
            0,
            0,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            2,
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
        11.9,
        1,
        6
      ],
      "to": [
        11.9,
        7,
        10
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          12,
          6.1,
          7.9
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            10.5,
            5.5,
            12.5,
            8.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            11,
            2.5,
            13,
            5.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0,
            2,
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
            2
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        10,
        -2,
        8
      ],
      "to": [
        14,
        2,
        8
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          12,
          1.1,
          8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            12,
            0,
            14,
            2
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            4,
            12,
            6,
            14
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            2,
            0,
            0,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            2,
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
        12,
        -2,
        6.1
      ],
      "to": [
        12,
        2,
        10.1
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          12,
          1.1,
          8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            12.5,
            5.5,
            14.5,
            7.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            13,
            2,
            15,
            4
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0,
            2,
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
            2
          ],
          "texture": "#0"
        }
      }
    }
  ],
  "display": {
    "thirdperson_righthand": {
      "rotation": [
        67.75,
        0,
        0
      ],
      "translation": [
        0,
        -2.75,
        -6.25
      ]
    },
    "thirdperson_lefthand": {
      "rotation": [
        67.75,
        0,
        0
      ],
      "translation": [
        0,
        -2.75,
        -6.25
      ]
    },
    "firstperson_righthand": {
      "rotation": [
        0,
        16.75,
        0
      ]
    },
    "firstperson_lefthand": {
      "rotation": [
        0,
        16.75,
        0
      ]
    }
  }
}
'@

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/blockstates/ceiling_plant.json" `
@'
{
  "variants": {
    "rotation=0": { "model": "minecraft:block/air" },
    "rotation=1": { "model": "minecraft:block/air" },
    "rotation=2": { "model": "minecraft:block/air" },
    "rotation=3": { "model": "minecraft:block/air" },
    "rotation=4": { "model": "minecraft:block/air" },
    "rotation=5": { "model": "minecraft:block/air" },
    "rotation=6": { "model": "minecraft:block/air" },
    "rotation=7": { "model": "minecraft:block/air" },
    "rotation=8": { "model": "minecraft:block/air" },
    "rotation=9": { "model": "minecraft:block/air" },
    "rotation=10": { "model": "minecraft:block/air" },
    "rotation=11": { "model": "minecraft:block/air" },
    "rotation=12": { "model": "minecraft:block/air" },
    "rotation=13": { "model": "minecraft:block/air" },
    "rotation=14": { "model": "minecraft:block/air" },
    "rotation=15": { "model": "minecraft:block/air" }
  }
}
'@

$TexturePath = Join-Path $Root "src/main/resources/assets/droingos_decor/textures/block/potted_plant_ceiling.png"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $TexturePath) | Out-Null
[System.IO.File]::WriteAllBytes(
        $TexturePath,
        [Convert]::FromBase64String("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")
)

$LangRelative = "src/main/resources/assets/droingos_decor/lang/en_us.json"
$LangPath = Join-Path $Root $LangRelative
Backup-File $LangRelative

if (Test-Path -LiteralPath $LangPath) {
    $Lang = Get-Content -LiteralPath $LangPath -Raw | ConvertFrom-Json
} else {
    $Lang = [pscustomobject]@{}
}

$Lang | Add-Member `
    -NotePropertyName "item.droingos_decor.potted_plant_ceiling" `
    -NotePropertyValue "Hanging Potted Plant" `
    -Force

[System.IO.File]::WriteAllText(
        $LangPath,
        ($Lang | ConvertTo-Json -Depth 20),
        $Utf8NoBom
)

Write-Host ""
Write-Host "Added Hanging Potted Plant."
Write-Host "Backup directory: $BackupRoot"
Write-Host ""
Write-Host "Building..."
Write-Host ""

& .\gradlew.bat build

if ($LASTEXITCODE -ne 0) {
    throw "Build failed. Send the compile output. Backup: $BackupRoot"
}

Write-Host ""
Write-Host "Build successful."
Write-Host ""
Write-Host "Test:"
Write-Host "  1. It appears under Hanging Decor."
Write-Host "  2. It places only on ceiling undersides."
Write-Host "  3. The whole plant hangs toward world gravity."
Write-Host "  4. Vine segments 1-3 trail progressively."
Write-Host "  5. Normal right-click does nothing."
Write-Host "  6. Sneak-right-click rotates it."
