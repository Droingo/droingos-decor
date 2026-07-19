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

Write-Utf8NoBom "src/main/java/net/droingo/decor/entity/TinyDecorEntity.java" @'
package net.droingo.decor.entity;

import net.droingo.decor.registry.DecorDefinitionRegistry;
import net.droingo.decor.registry.DecorEntities;
import net.droingo.decor.registry.DecorSounds;
import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.Mth;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.SupportType;
import net.minecraft.world.phys.Vec3;

public final class TinyDecorEntity extends Entity {
    private static final EntityDataAccessor<String> DECOR_ID =
            SynchedEntityData.defineId(
                    TinyDecorEntity.class,
                    EntityDataSerializers.STRING
            );

    private static final EntityDataAccessor<Integer> ROTATION =
            SynchedEntityData.defineId(
                    TinyDecorEntity.class,
                    EntityDataSerializers.INT
            );

    private static final EntityDataAccessor<Integer> PULSE =
            SynchedEntityData.defineId(
                    TinyDecorEntity.class,
                    EntityDataSerializers.INT
            );

    public TinyDecorEntity(
            EntityType<? extends TinyDecorEntity> type,
            Level level
    ) {
        super(type, level);
        noPhysics = true;
        setNoGravity(true);
    }

    public TinyDecorEntity(
            Level level,
            ResourceLocation decorId,
            double x,
            double y,
            double z,
            int rotation
    ) {
        this(
                DecorEntities.TINY_DECOR.get(),
                level
        );

        setDecorId(decorId);
        setRotationStep(rotation);
        moveTo(x, y, z, rotation * 22.5F, 0.0F);
    }

    @Override
    protected void defineSynchedData(
            SynchedEntityData.Builder builder
    ) {
        builder.define(DECOR_ID, "");
        builder.define(ROTATION, 0);
        builder.define(PULSE, 0);
    }

    public ResourceLocation getDecorId() {
        return ResourceLocation.tryParse(
                entityData.get(DECOR_ID)
        );
    }

    public void setDecorId(ResourceLocation id) {
        entityData.set(
                DECOR_ID,
                id == null ? "" : id.toString()
        );
    }

    public int getRotationStep() {
        return entityData.get(ROTATION) & 15;
    }

    public void setRotationStep(int rotation) {
        int value = rotation & 15;
        entityData.set(ROTATION, value);
        setYRot(value * 22.5F);
    }

    public int getPulseCounter() {
        return entityData.get(PULSE);
    }

    public void pulse() {
        entityData.set(
                PULSE,
                entityData.get(PULSE) + 1
        );
    }

    @Override
    public void tick() {
        super.tick();
        noPhysics = true;
        setNoGravity(true);
        setDeltaMovement(Vec3.ZERO);

        if (!level().isClientSide && tickCount % 20 == 0) {
            BlockPos support = BlockPos.containing(
                    getX(),
                    getY() - 0.0625D,
                    getZ()
            );

            if (!level().getBlockState(support).isFaceSturdy(
                    level(),
                    support,
                    net.minecraft.core.Direction.UP,
                    SupportType.CENTER
            )) {
                dropAndDiscard(null);
            }
        }
    }

    @Override
    public InteractionResult interact(
            Player player,
            InteractionHand hand
    ) {
        if (player.isShiftKeyDown()) {
            if (!level().isClientSide) {
                setRotationStep(getRotationStep() + 1);
            }

            return InteractionResult.sidedSuccess(
                    level().isClientSide
            );
        }

        if (!level().isClientSide) {
            pulse();
            playInteractionSound();
        }

        return InteractionResult.sidedSuccess(
                level().isClientSide
        );
    }

    private void playInteractionSound() {
        ResourceLocation id = getDecorId();

        if (id == null) {
            return;
        }

        float pitch =
                0.90F
                        + level().random.nextFloat()
                        * 0.20F;

        switch (id.getPath()) {
            case "bobble_parrot" ->
                    level().playSound(
                            null,
                            blockPosition(),
                            SoundEvents.PARROT_AMBIENT,
                            SoundSource.BLOCKS,
                            0.8F,
                            1.35F
                                    + level().random.nextFloat()
                                    * 0.20F
                    );

            case "buddy_bobblehead" ->
                    level().playSound(
                            null,
                            blockPosition(),
                            SoundEvents.WOLF_AMBIENT,
                            SoundSource.BLOCKS,
                            0.8F,
                            1.35F
                                    + level().random.nextFloat()
                                    * 0.15F
                    );

            case "pumpkin_bobble" ->
                    level().playSound(
                            null,
                            blockPosition(),
                            DecorSounds.PUMPKIN_CAW.get(),
                            SoundSource.BLOCKS,
                            0.8F,
                            pitch
                    );

            default -> {
            }
        }
    }

    @Override
    public boolean hurtServer(
            ServerLevel level,
            DamageSource source,
            float amount
    ) {
        Entity attacker = source.getEntity();

        if (attacker instanceof Player player) {
            dropAndDiscard(player);
            return true;
        }

        return false;
    }

    private void dropAndDiscard(Player player) {
        ResourceLocation id = getDecorId();

        if (id != null) {
            var definition =
                    DecorDefinitionRegistry.get(id);

            if (definition != null) {
                ItemStack stack =
                        definition.pickupStack();

                if (
                        player != null
                                && player.getAbilities()
                                .instabuild
                ) {
                    discard();
                    return;
                }

                spawnAtLocation(stack);
            }
        }

        discard();
    }

    @Override
    protected void readAdditionalSaveData(
            CompoundTag tag
    ) {
        setDecorId(
                ResourceLocation.tryParse(
                        tag.getString("DecorId")
                )
        );

        setRotationStep(
                tag.getInt("Rotation")
        );
    }

    @Override
    protected void addAdditionalSaveData(
            CompoundTag tag
    ) {
        ResourceLocation id = getDecorId();

        if (id != null) {
            tag.putString(
                    "DecorId",
                    id.toString()
            );
        }

        tag.putInt(
                "Rotation",
                getRotationStep()
        );
    }

    @Override
    public boolean isPickable() {
        return true;
    }

    @Override
    public boolean isPushable() {
        return false;
    }

    @Override
    public boolean canBeCollidedWith() {
        return false;
    }
}
'@

Write-Utf8NoBom "src/main/java/net/droingo/decor/client/render/TinyDecorEntityRenderer.java" @'
package net.droingo.decor.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;
import dev.ryanhcode.sable.Sable;
import net.droingo.decor.api.BobbleheadRenderDefinition;
import net.droingo.decor.api.DecorDefinition;
import net.droingo.decor.client.animation.BobbleheadMotionState;
import net.droingo.decor.entity.TinyDecorEntity;
import net.droingo.decor.registry.DecorDefinitionRegistry;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.block.BlockRenderDispatcher;
import net.minecraft.client.renderer.entity.EntityRenderer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.state.EntityRenderState;
import net.minecraft.client.resources.model.BakedModel;
import net.minecraft.client.resources.model.ModelResourceLocation;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.phys.Vec3;
import net.neoforged.neoforge.client.model.data.ModelData;
import org.joml.Vector3d;

import java.util.Map;
import java.util.WeakHashMap;

public final class TinyDecorEntityRenderer
        extends EntityRenderer<
        TinyDecorEntity,
        TinyDecorEntityRenderer.State
        > {

    private final BlockRenderDispatcher blockRenderer;
    private final Map<TinyDecorEntity, BobbleheadMotionState>
            motionStates = new WeakHashMap<>();
    private final Map<TinyDecorEntity, Integer>
            pulseCounters = new WeakHashMap<>();

    public TinyDecorEntityRenderer(
            EntityRendererProvider.Context context
    ) {
        super(context);
        blockRenderer =
                Minecraft.getInstance()
                        .getBlockRenderer();
        shadowRadius = 0.0F;
    }

    @Override
    public State createRenderState() {
        return new State();
    }

    @Override
    public void extractRenderState(
            TinyDecorEntity entity,
            State state,
            float partialTick
    ) {
        super.extractRenderState(
                entity,
                state,
                partialTick
        );

        state.entity = entity;
        state.partialTick = partialTick;
    }

    @Override
    public void render(
            State state,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight
    ) {
        TinyDecorEntity entity =
                state.entity;

        if (entity == null) {
            return;
        }

        ResourceLocation id =
                entity.getDecorId();

        DecorDefinition definition =
                id == null
                        ? null
                        : DecorDefinitionRegistry.get(id);

        if (
                definition == null
                        || definition.bobbleheadRender()
                        == null
        ) {
            return;
        }

        BobbleheadRenderDefinition render =
                definition.bobbleheadRender();

        BobbleheadMotionState motion =
                motionStates.computeIfAbsent(
                        entity,
                        ignored ->
                                new BobbleheadMotionState()
                );

        int pulse =
                entity.getPulseCounter();

        Integer previous =
                pulseCounters.put(entity, pulse);

        if (
                previous != null
                        && pulse != previous
        ) {
            motion.addInteractionImpulse();
        }

        float yaw =
                entity.getRotationStep()
                        * 22.5F;

        updateMotion(
                entity,
                motion,
                yaw,
                render.pivot().y,
                state.partialTick
        );

        poseStack.pushPose();
        poseStack.mulPose(
                Axis.YP.rotationDegrees(yaw)
        );
        poseStack.scale(
                render.scale(),
                render.scale(),
                render.scale()
        );
        poseStack.translate(
                -0.5D,
                0.0D,
                -0.5D
        );

        renderModel(
                poseStack,
                buffers,
                render.bodyModel(),
                packedLight
        );

        Vector3d pivot =
                render.pivot();

        poseStack.pushPose();
        poseStack.translate(
                pivot.x,
                pivot.y,
                pivot.z
        );
        poseStack.mulPose(
                Axis.XP.rotationDegrees(
                        motion.getPitchDegrees()
                )
        );
        poseStack.mulPose(
                Axis.ZP.rotationDegrees(
                        motion.getRollDegrees()
                )
        );
        poseStack.translate(
                -pivot.x,
                -pivot.y,
                -pivot.z
        );

        renderModel(
                poseStack,
                buffers,
                render.movingModel(),
                packedLight
        );

        poseStack.popPose();
        poseStack.popPose();

        super.render(
                state,
                poseStack,
                buffers,
                packedLight
        );
    }

    private static void updateMotion(
            TinyDecorEntity entity,
            BobbleheadMotionState motion,
            float yawDegrees,
            double pivotY,
            float partialTick
    ) {
        Vec3 localOrigin =
                new Vec3(
                        entity.getX(),
                        entity.getY() + pivotY,
                        entity.getZ()
                );

        Vec3 worldOrigin =
                Sable.HELPER.projectOutOfSubLevel(
                        entity.level(),
                        localOrigin
                );

        Vec3 worldX =
                Sable.HELPER.projectOutOfSubLevel(
                        entity.level(),
                        localOrigin.add(
                                1.0D,
                                0.0D,
                                0.0D
                        )
                ).subtract(worldOrigin);

        Vec3 worldZ =
                Sable.HELPER.projectOutOfSubLevel(
                        entity.level(),
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

        double yawRadians =
                Math.toRadians(yawDegrees);

        double cos =
                Math.cos(yawRadians);

        double sin =
                Math.sin(yawRadians);

        Vec3 right =
                worldX.scale(cos)
                        .add(
                                worldZ.scale(sin)
                        )
                        .normalize();

        Vec3 forward =
                worldX.scale(sin)
                        .add(
                                worldZ.scale(-cos)
                        )
                        .normalize();

        motion.update(
                entity.level().getGameTime()
                        + partialTick,
                worldOrigin,
                right,
                forward
        );
    }

    private void renderModel(
            PoseStack poseStack,
            MultiBufferSource buffers,
            ResourceLocation location,
            int light
    ) {
        BakedModel model =
                Minecraft.getInstance()
                        .getModelManager()
                        .getModel(
                                ModelResourceLocation
                                        .standalone(location)
                        );

        VertexConsumer consumer =
                buffers.getBuffer(
                        RenderType.cutout()
                );

        blockRenderer.getModelRenderer()
                .renderModel(
                        poseStack.last(),
                        consumer,
                        Blocks.AIR
                                .defaultBlockState(),
                        model,
                        1.0F,
                        1.0F,
                        1.0F,
                        light,
                        net.minecraft.client.renderer
                                .texture.OverlayTexture
                                .NO_OVERLAY,
                        ModelData.EMPTY,
                        RenderType.cutout()
                );
    }

    public static final class State
            extends EntityRenderState {
        private TinyDecorEntity entity;
        private float partialTick;
    }
}
'@

Write-Utf8NoBom "src/main/java/net/droingo/decor/content/TinyDecorItem.java" @'
package net.droingo.decor.content;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.entity.TinyDecorEntity;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.Mth;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.context.UseOnContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.properties.AttachFace;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;

public final class TinyDecorItem extends Item {
    private final ResourceLocation decorId;

    public TinyDecorItem(
            String id,
            Properties properties
    ) {
        super(properties);

        decorId =
                ResourceLocation.fromNamespaceAndPath(
                        DroingosDecor.MOD_ID,
                        id
                );
    }

    @Override
    public InteractionResult useOn(
            UseOnContext context
    ) {
        Level level = context.getLevel();

        BlockPos clickedPos =
                context.getClickedPos();

        BlockState clickedState =
                level.getBlockState(clickedPos);

        BlockPos supportPos =
                resolveSupportBlock(
                        clickedPos,
                        clickedState
                );

        if (
                supportPos.equals(clickedPos)
                        && context.getClickedFace()
                        != Direction.UP
        ) {
            return InteractionResult.PASS;
        }

        BlockState supportState =
                level.getBlockState(supportPos);

        if (
                !supportState.isFaceSturdy(
                        level,
                        supportPos,
                        Direction.UP,
                        net.minecraft.world.level.block
                                .SupportType.CENTER
                )
        ) {
            return InteractionResult.FAIL;
        }

        double localX =
                context.getClickLocation().x
                        - supportPos.getX();

        double localZ =
                context.getClickLocation().z
                        - supportPos.getZ();

        double snappedX =
                snapPixel(
                        Mth.clamp(
                                localX,
                                1.0D / 16.0D,
                                15.0D / 16.0D
                        )
                );

        double snappedZ =
                snapPixel(
                        Mth.clamp(
                                localZ,
                                1.0D / 16.0D,
                                15.0D / 16.0D
                        )
                );

        double x =
                supportPos.getX()
                        + snappedX;

        double y =
                supportPos.getY()
                        + 1.0D;

        double z =
                supportPos.getZ()
                        + snappedZ;

        int rotation =
                Mth.floor(
                        (
                                context.getRotation()
                                        + 11.25F
                        ) / 22.5F
                ) & 15;

        if (!level.isClientSide) {
            TinyDecorEntity entity =
                    new TinyDecorEntity(
                            level,
                            decorId,
                            x,
                            y,
                            z,
                            rotation
                    );

            level.addFreshEntity(entity);

            SoundType sound =
                    supportState.getSoundType(
                            level,
                            supportPos,
                            context.getPlayer()
                    );

            level.playSound(
                    null,
                    supportPos,
                    sound.getPlaceSound(),
                    SoundSource.BLOCKS,
                    (sound.getVolume() + 1.0F)
                            / 2.0F,
                    sound.getPitch() * 0.8F
            );

            if (
                    context.getPlayer() == null
                            || !context.getPlayer()
                            .getAbilities()
                            .instabuild
            ) {
                context.getItemInHand()
                        .shrink(1);
            }
        }

        return InteractionResult.sidedSuccess(
                level.isClientSide
        );
    }

    private static double snapPixel(
            double value
    ) {
        return Math.round(value * 16.0D)
                / 16.0D;
    }

    private static BlockPos resolveSupportBlock(
            BlockPos clickedPos,
            BlockState state
    ) {
        if (
                !state.hasProperty(
                        BlockStateProperties.ATTACH_FACE
                )
                        || !state.hasProperty(
                        BlockStateProperties
                                .HORIZONTAL_FACING
                )
        ) {
            return clickedPos;
        }

        AttachFace attachFace =
                state.getValue(
                        BlockStateProperties.ATTACH_FACE
                );

        return switch (attachFace) {
            case FLOOR ->
                    clickedPos.below();

            case CEILING ->
                    clickedPos.above();

            case WALL ->
                    clickedPos.relative(
                            state.getValue(
                                            BlockStateProperties
                                                    .HORIZONTAL_FACING
                                    )
                                    .getOpposite()
                    );
        };
    }

    public static int slotFromHit(
            double x,
            double z
    ) {
        return (
                z >= 0.5D
                        ? 2
                        : 0
        ) + (
                x >= 0.5D
                        ? 1
                        : 0
        );
    }
}
'@

# Add TinyDecorEntity registration without replacing the existing skull seat.
$EntitiesPath = Join-Path $Root "src/main/java/net/droingo/decor/registry/DecorEntities.java"
$EntitiesText = [System.IO.File]::ReadAllText($EntitiesPath)

if (-not $EntitiesText.Contains("TinyDecorEntity")) {
    $EntitiesText = $EntitiesText.Replace(
        "import net.droingo.decor.entity.BeastSkullSeatEntity;",
        "import net.droingo.decor.entity.BeastSkullSeatEntity;`r`nimport net.droingo.decor.entity.TinyDecorEntity;"
    )

    $Marker = "    private DecorEntities() {"

    $Registration = @'
    public static final DeferredHolder<EntityType<?>, EntityType<TinyDecorEntity>> TINY_DECOR =
            ENTITY_TYPES.register(
                    "tiny_decor",
                    () -> EntityType.Builder
                            .<TinyDecorEntity>of(
                                    TinyDecorEntity::new,
                                    MobCategory.MISC
                            )
                            .sized(0.45F, 0.75F)
                            .clientTrackingRange(10)
                            .updateInterval(1)
                            .build("tiny_decor")
            );

'@

    $EntitiesText = $EntitiesText.Replace(
        $Marker,
        $Registration + $Marker
    )
}

[System.IO.File]::WriteAllText(
    $EntitiesPath,
    $EntitiesText,
    $Utf8NoBom
)

# Register the entity renderer.
$ClientPath = Join-Path $Root "src/main/java/net/droingo/decor/client/DroingosDecorClient.java"
$ClientText = [System.IO.File]::ReadAllText($ClientPath)

if (-not $ClientText.Contains("TinyDecorEntityRenderer")) {
    $ClientText = $ClientText.Replace(
        "import net.droingo.decor.client.render.WallDecorRenderer;",
        "import net.droingo.decor.client.render.WallDecorRenderer;`r`nimport net.droingo.decor.client.render.TinyDecorEntityRenderer;"
    )

    $Needle = @'
        event.registerEntityRenderer(
                DecorEntities.BEAST_SKULL_SEAT.get(),
                BeastSkullSeatRenderer::new
        );
'@

    $Replacement = $Needle + @'
        event.registerEntityRenderer(
                DecorEntities.TINY_DECOR.get(),
                TinyDecorEntityRenderer::new
        );
'@

    $ClientText = $ClientText.Replace(
        $Needle,
        $Replacement
    )
}

[System.IO.File]::WriteAllText(
    $ClientPath,
    $ClientText,
    $Utf8NoBom
)

# Correct only the Beast Skull wall east/west mapping.
$SkullPath = Join-Path $Root "src/main/java/net/droingo/decor/client/render/BeastSkullRenderer.java"
$SkullText = [System.IO.File]::ReadAllText($SkullPath)

$OldWallYaw = @'
            return outward.toYRot() + 180.0F;
'@

$NewWallYaw = @'
            return switch (outward) {
                case NORTH -> 180.0F;
                case SOUTH -> 0.0F;
                case EAST -> -90.0F;
                case WEST -> 90.0F;
                default -> 0.0F;
            };
'@

if ($SkullText.Contains($OldWallYaw)) {
    $SkullText = $SkullText.Replace(
        $OldWallYaw,
        $NewWallYaw
    )
}

[System.IO.File]::WriteAllText(
    $SkullPath,
    $SkullText,
    $Utf8NoBom
)

Write-Host ""
Write-Host "Installed pixel-positioned, non-blocking tiny decor entities."
Write-Host "Also corrected Beast Skull east/west wall rotation."
Write-Host ""
Write-Host "Existing container bobbleheads are left in place and remain usable."
Write-Host "All newly placed tiny decor uses the entity system."
Write-Host ""
Write-Host "Building..."
Write-Host ""

& ".\gradlew.bat" build

if ($LASTEXITCODE -ne 0) {
    throw "Build failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Build successful."
