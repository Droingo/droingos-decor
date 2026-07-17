$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$root = (Get-Location).Path
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupRoot = Join-Path $root (".decor_refactor_backup_" + $stamp)
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null

function Write-Utf8NoBom([string]$RelativePath, [string]$Content) {
    $target = Join-Path $root $RelativePath
    $parent = Split-Path -Parent $target
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    if (Test-Path -LiteralPath $target) {
        $safeName = ($RelativePath -replace '[\/:*?"<>|]', '_')
        Copy-Item -LiteralPath $target -Destination (Join-Path $backupRoot $safeName) -Force
    }
    [System.IO.File]::WriteAllText($target, $Content, $utf8NoBom)
}

Write-Utf8NoBom 'src/main/java/net/droingo/decor/api/DecorCategory.java' @'
package net.droingo.decor.api;

import net.minecraft.network.chat.Component;

public enum DecorCategory {
    BOBBLEHEADS("bobbleheads", 0),
    WALL_DECOR("wall_decor", 10),
    HANGING_DECOR("hanging_decor", 20),
    SMALL_DECOR("small_decor", 30),
    FURNITURE("furniture", 40),
    LIGHTING("lighting", 50),
    OUTDOOR_DECOR("outdoor_decor", 60);

    private final String translationKeyPart;
    private final int order;

    DecorCategory(String translationKeyPart, int order) {
        this.translationKeyPart = translationKeyPart;
        this.order = order;
    }

    public Component title() {
        return Component.translatable("itemGroup.droingos_decor.category." + translationKeyPart);
    }

    public int order() {
        return order;
    }
}
'@

Write-Utf8NoBom 'src/main/java/net/droingo/decor/api/DecorPlacementType.java' @'
package net.droingo.decor.api;

public enum DecorPlacementType {
    TINY,
    SMALL,
    WIDE,
    FULL,
    LARGE,
    WALL,
    HANGING
}
'@

Write-Utf8NoBom 'src/main/java/net/droingo/decor/api/DecorInteraction.java' @'
package net.droingo.decor.api;

import net.droingo.decor.content.DecorContainerBlockEntity;
import net.minecraft.core.BlockPos;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;

@FunctionalInterface
public interface DecorInteraction {
    DecorInteraction NONE = (level, pos, player, container, slot) ->
            InteractionResult.sidedSuccess(level.isClientSide);

    InteractionResult interact(
            Level level,
            BlockPos pos,
            Player player,
            DecorContainerBlockEntity container,
            int slot
    );
}
'@

Write-Utf8NoBom 'src/main/java/net/droingo/decor/api/BobbleheadRenderDefinition.java' @'
package net.droingo.decor.api;

import net.minecraft.resources.ResourceLocation;
import org.joml.Vector3d;

public record BobbleheadRenderDefinition(
        ResourceLocation bodyModel,
        ResourceLocation movingModel,
        Vector3d pivot,
        float scale
) {
}
'@

Write-Utf8NoBom 'src/main/java/net/droingo/decor/api/DecorDefinition.java' @'
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
    }

    public static Builder builder(ResourceLocation id) {
        return new Builder(id);
    }

    public ResourceLocation id() { return id; }
    public DecorCategory category() { return category; }
    public DecorPlacementType placementType() { return placementType; }
    public DecorInteraction interaction() { return interaction; }
    public double minX() { return minX; }
    public double minY() { return minY; }
    public double minZ() { return minZ; }
    public double maxX() { return maxX; }
    public double maxY() { return maxY; }
    public double maxZ() { return maxZ; }
    public @Nullable BobbleheadRenderDefinition bobbleheadRender() { return bobbleheadRender; }

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
                double minX, double minY, double minZ,
                double maxX, double maxY, double maxZ
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

        public DecorDefinition build() {
            if (itemSupplier == null) {
                throw new IllegalStateException("Decor definition " + id + " has no item supplier");
            }
            return new DecorDefinition(this);
        }
    }
}
'@

Write-Utf8NoBom 'src/main/java/net/droingo/decor/registry/DecorDefinitionRegistry.java' @'
package net.droingo.decor.registry;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.api.BobbleheadRenderDefinition;
import net.droingo.decor.api.DecorCategory;
import net.droingo.decor.api.DecorDefinition;
import net.droingo.decor.api.DecorPlacementType;
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
    private static final Map<ResourceLocation, DecorDefinition> DEFINITIONS = new LinkedHashMap<>();
    private static boolean bootstrapped;

    private DecorDefinitionRegistry() {
    }

    public static void bootstrap() {
        if (bootstrapped) {
            return;
        }
        bootstrapped = true;

        ResourceLocation parrotId = id("bobble_parrot");

        register(DecorDefinition.builder(parrotId)
                .category(DecorCategory.BOBBLEHEADS)
                .placement(DecorPlacementType.TINY)
                .item(DecorItems.BOBBLE_PARROT::get)
                .bounds(-0.118D, 0.0D, -0.238D, 0.118D, 0.755D, 0.141D)
                .bobblehead(new BobbleheadRenderDefinition(
                        model("bobble_parrot_body"),
                        model("bobble_parrot_head"),
                        new Vector3d(8.0D / 16.0D, 3.2D / 16.0D, 7.3D / 16.0D),
                        1.5F
                ))
                .interaction((level, pos, player, container, slot) -> {
                    if (!level.isClientSide) {
                        float pitch = 1.45F + level.random.nextFloat() * 0.25F;
                        level.playSound(null, pos, SoundEvents.PARROT_AMBIENT, SoundSource.BLOCKS, 0.85F, pitch);
                    }
                    return net.minecraft.world.InteractionResult.sidedSuccess(level.isClientSide);
                })
                .build());
    }

    public static DecorDefinition register(DecorDefinition definition) {
        DecorDefinition previous = DEFINITIONS.putIfAbsent(definition.id(), definition);
        if (previous != null) {
            throw new IllegalStateException("Duplicate decor definition: " + definition.id());
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
        List<DecorDefinition> ordered = new ArrayList<>(DEFINITIONS.values());
        ordered.sort(Comparator
                .comparingInt((DecorDefinition definition) -> definition.category().order())
                .thenComparing(definition -> definition.id().toString()));
        return ordered;
    }

    private static ResourceLocation id(String path) {
        return ResourceLocation.fromNamespaceAndPath(DroingosDecor.MOD_ID, path);
    }

    private static ResourceLocation model(String path) {
        return ResourceLocation.fromNamespaceAndPath(DroingosDecor.MOD_ID, "block/" + path);
    }
}
'@

Write-Utf8NoBom 'src/main/java/net/droingo/decor/content/DecorShapes.java' @'
package net.droingo.decor.content;

import net.droingo.decor.api.DecorDefinition;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;

public final class DecorShapes {
    private DecorShapes() {
    }

    public static VoxelShape rotatedTinyShape(
            DecorDefinition definition,
            int slot,
            int rotationStep
    ) {
        double centreX = slot % 2 == 0 ? 0.25D : 0.75D;
        double centreZ = slot < 2 ? 0.25D : 0.75D;

        double angleRadians = Math.toRadians(rotationStep * 22.5D);
        double cos = Math.cos(angleRadians);
        double sin = Math.sin(angleRadians);

        double minX = Double.POSITIVE_INFINITY;
        double maxX = Double.NEGATIVE_INFINITY;
        double minZ = Double.POSITIVE_INFINITY;
        double maxZ = Double.NEGATIVE_INFINITY;

        double[] xCorners = {definition.minX(), definition.maxX()};
        double[] zCorners = {definition.minZ(), definition.maxZ()};

        for (double localX : xCorners) {
            for (double localZ : zCorners) {
                double rotatedX = localX * cos + localZ * sin;
                double rotatedZ = -localX * sin + localZ * cos;

                minX = Math.min(minX, centreX + rotatedX);
                maxX = Math.max(maxX, centreX + rotatedX);
                minZ = Math.min(minZ, centreZ + rotatedZ);
                maxZ = Math.max(maxZ, centreZ + rotatedZ);
            }
        }

        return Shapes.box(
                clamp(minX), definition.minY(), clamp(minZ),
                clamp(maxX), definition.maxY(), clamp(maxZ)
        );
    }

    private static double clamp(double value) {
        return Math.max(0.0D, Math.min(1.0D, value));
    }
}
'@

Write-Utf8NoBom 'src/main/java/net/droingo/decor/content/DecorContainerBlock.java' @'
package net.droingo.decor.content;

import com.mojang.serialization.MapCodec;
import net.droingo.decor.api.DecorDefinition;
import net.droingo.decor.registry.DecorDefinitionRegistry;
import net.minecraft.core.BlockPos;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.BaseEntityBlock;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.HitResult;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;
import org.jetbrains.annotations.Nullable;

public final class DecorContainerBlock extends BaseEntityBlock {
    public static final MapCodec<DecorContainerBlock> CODEC = simpleCodec(DecorContainerBlock::new);

    public DecorContainerBlock(Properties properties) {
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
        return new DecorContainerBlockEntity(pos, state);
    }

    @Override
    protected float getDestroyProgress(BlockState state, Player player, BlockGetter level, BlockPos pos) {
        return 0.0F;
    }

    @Override
    protected VoxelShape getShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context) {
        return buildDecorShape(level, pos);
    }

    @Override
    protected VoxelShape getCollisionShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context) {
        return buildDecorShape(level, pos);
    }

    private VoxelShape buildDecorShape(BlockGetter level, BlockPos pos) {
        if (!(level.getBlockEntity(pos) instanceof DecorContainerBlockEntity container)) {
            return Shapes.empty();
        }

        VoxelShape combined = Shapes.empty();

        for (int slot = 0; slot < 4; slot++) {
            ResourceLocation id = container.getDecorId(slot);
            DecorDefinition definition = id == null ? null : DecorDefinitionRegistry.get(id);

            if (definition != null) {
                combined = Shapes.or(combined, DecorShapes.rotatedTinyShape(
                        definition,
                        slot,
                        container.getRotation(slot)
                ));
            }
        }

        return combined.optimize();
    }

    @Override
    protected InteractionResult useWithoutItem(
            BlockState state,
            Level level,
            BlockPos pos,
            Player player,
            BlockHitResult hit
    ) {
        if (!(level.getBlockEntity(pos) instanceof DecorContainerBlockEntity container)) {
            return InteractionResult.PASS;
        }

        int slot = slotFromHit(pos, hit);
        ResourceLocation id = container.getDecorId(slot);
        DecorDefinition definition = id == null ? null : DecorDefinitionRegistry.get(id);

        if (definition == null) {
            return InteractionResult.PASS;
        }

        if (player.isShiftKeyDown()) {
            if (!level.isClientSide) {
                container.rotate(slot);
            }
            return InteractionResult.sidedSuccess(level.isClientSide);
        }

        return definition.interaction().interact(level, pos, player, container, slot);
    }

    @Override
    public void attack(BlockState state, Level level, BlockPos pos, Player player) {
        super.attack(state, level, pos, player);

        if (level.isClientSide || !(level.getBlockEntity(pos) instanceof DecorContainerBlockEntity container)) {
            return;
        }

        HitResult picked = player.pick(5.0D, 1.0F, false);
        if (!(picked instanceof BlockHitResult blockHit) || !blockHit.getBlockPos().equals(pos)) {
            return;
        }

        int slot = slotFromHit(pos, blockHit);
        ResourceLocation id = container.getDecorId(slot);
        DecorDefinition definition = id == null ? null : DecorDefinitionRegistry.get(id);

        if (definition == null || container.remove(slot) == null) {
            return;
        }

        if (!player.getAbilities().instabuild) {
            ItemStack stack = definition.pickupStack();
            if (!player.getInventory().add(stack)) {
                popResource(level, pos, stack);
            }
        }

        if (container.isCompletelyEmpty()) {
            level.removeBlock(pos, false);
        }
    }

    private static int slotFromHit(BlockPos pos, BlockHitResult hit) {
        return TinyDecorItem.slotFromHit(
                hit.getLocation().x - pos.getX(),
                hit.getLocation().z - pos.getZ()
        );
    }
}
'@

Write-Utf8NoBom 'src/main/java/net/droingo/decor/client/render/DecorContainerRenderer.java' @'
package net.droingo.decor.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;
import dev.ryanhcode.sable.Sable;
import net.droingo.decor.api.BobbleheadRenderDefinition;
import net.droingo.decor.api.DecorDefinition;
import net.droingo.decor.client.animation.BobbleheadMotionState;
import net.droingo.decor.content.DecorContainerBlockEntity;
import net.droingo.decor.registry.DecorDefinitionRegistry;
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
import org.joml.Vector3d;

import java.util.Map;
import java.util.WeakHashMap;

public final class DecorContainerRenderer implements BlockEntityRenderer<DecorContainerBlockEntity> {
    private final Map<DecorContainerBlockEntity, BobbleheadMotionState[]> motionStates = new WeakHashMap<>();
    private final BlockRenderDispatcher blockRenderer;

    public DecorContainerRenderer(BlockEntityRendererProvider.Context context) {
        this.blockRenderer = context.getBlockRenderDispatcher();
    }

    @Override
    public void render(
            DecorContainerBlockEntity blockEntity,
            float partialTick,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        for (int slot = 0; slot < 4; slot++) {
            ResourceLocation id = blockEntity.getDecorId(slot);
            DecorDefinition definition = id == null ? null : DecorDefinitionRegistry.get(id);

            if (definition == null || definition.bobbleheadRender() == null) {
                continue;
            }

            renderBobblehead(
                    blockEntity,
                    definition,
                    slot,
                    partialTick,
                    poseStack,
                    buffers,
                    packedLight,
                    packedOverlay
            );
        }
    }

    private void renderBobblehead(
            DecorContainerBlockEntity blockEntity,
            DecorDefinition definition,
            int slot,
            float partialTick,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        BobbleheadRenderDefinition render = definition.bobbleheadRender();
        double centreX = slot % 2 == 0 ? 0.25D : 0.75D;
        double centreZ = slot < 2 ? 0.25D : 0.75D;
        float yawDegrees = blockEntity.getRotation(slot) * 22.5F;

        BobbleheadMotionState motion = getMotionState(blockEntity, slot);
        updateMotion(blockEntity, motion, centreX, centreZ, yawDegrees, render.pivot().y, partialTick);

        poseStack.pushPose();
        poseStack.translate(centreX, 0.0D, centreZ);
        poseStack.mulPose(Axis.YP.rotationDegrees(yawDegrees));
        poseStack.scale(render.scale(), render.scale(), render.scale());
        poseStack.translate(-0.5D, 0.0D, -0.5D);

        renderModel(poseStack, buffers, render.bodyModel(), packedLight, packedOverlay);
        renderMovingPart(poseStack, buffers, render, motion, packedLight, packedOverlay);
        poseStack.popPose();
    }

    private void updateMotion(
            DecorContainerBlockEntity blockEntity,
            BobbleheadMotionState motion,
            double centreX,
            double centreZ,
            float yawDegrees,
            double pivotY,
            float partialTick
    ) {
        Level level = blockEntity.getLevel();
        if (level == null) {
            return;
        }

        Vec3 localOrigin = new Vec3(
                blockEntity.getBlockPos().getX() + centreX,
                blockEntity.getBlockPos().getY() + pivotY,
                blockEntity.getBlockPos().getZ() + centreZ
        );

        Vec3 worldOrigin = Sable.HELPER.projectOutOfSubLevel(level, localOrigin);
        Vec3 worldLocalX = Sable.HELPER.projectOutOfSubLevel(level, localOrigin.add(1.0D, 0.0D, 0.0D)).subtract(worldOrigin);
        Vec3 worldLocalZ = Sable.HELPER.projectOutOfSubLevel(level, localOrigin.add(0.0D, 0.0D, 1.0D)).subtract(worldOrigin);

        if (worldLocalX.lengthSqr() < 0.000001D || worldLocalZ.lengthSqr() < 0.000001D) {
            return;
        }

        worldLocalX = worldLocalX.normalize();
        worldLocalZ = worldLocalZ.normalize();

        double yawRadians = Math.toRadians(yawDegrees);
        double cos = Math.cos(yawRadians);
        double sin = Math.sin(yawRadians);

        Vec3 decorRight = worldLocalX.scale(cos).add(worldLocalZ.scale(sin)).normalize();
        Vec3 decorForward = worldLocalX.scale(sin).add(worldLocalZ.scale(-cos)).normalize();

        motion.update(level.getGameTime() + partialTick, worldOrigin, decorRight, decorForward);
    }

    private BobbleheadMotionState getMotionState(DecorContainerBlockEntity blockEntity, int slot) {
        BobbleheadMotionState[] states = motionStates.computeIfAbsent(blockEntity, ignored -> new BobbleheadMotionState[4]);
        if (states[slot] == null) {
            states[slot] = new BobbleheadMotionState();
        }
        return states[slot];
    }

    private void renderMovingPart(
            PoseStack poseStack,
            MultiBufferSource buffers,
            BobbleheadRenderDefinition render,
            BobbleheadMotionState motion,
            int packedLight,
            int packedOverlay
    ) {
        Vector3d pivot = render.pivot();
        poseStack.pushPose();
        poseStack.translate(pivot.x, pivot.y, pivot.z);
        poseStack.mulPose(Axis.XP.rotationDegrees(motion.getPitchDegrees()));
        poseStack.mulPose(Axis.ZP.rotationDegrees(motion.getRollDegrees()));
        poseStack.translate(-pivot.x, -pivot.y, -pivot.z);
        renderModel(poseStack, buffers, render.movingModel(), packedLight, packedOverlay);
        poseStack.popPose();
    }

    private void renderModel(
            PoseStack poseStack,
            MultiBufferSource buffers,
            ResourceLocation location,
            int light,
            int overlay
    ) {
        BakedModel model = Minecraft.getInstance().getModelManager().getModel(ModelResourceLocation.standalone(location));
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
}
'@

Write-Utf8NoBom 'src/main/java/net/droingo/decor/client/DroingosDecorClient.java' @'
package net.droingo.decor.client;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.api.BobbleheadRenderDefinition;
import net.droingo.decor.api.DecorDefinition;
import net.droingo.decor.client.render.DecorContainerRenderer;
import net.droingo.decor.registry.DecorBlockEntities;
import net.droingo.decor.registry.DecorDefinitionRegistry;
import net.minecraft.client.resources.model.ModelResourceLocation;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.client.event.EntityRenderersEvent;
import net.neoforged.neoforge.client.event.ModelEvent;

@EventBusSubscriber(modid = DroingosDecor.MOD_ID, value = Dist.CLIENT, bus = EventBusSubscriber.Bus.MOD)
public final class DroingosDecorClient {
    private DroingosDecorClient() {
    }

    @SubscribeEvent
    public static void registerBlockEntityRenderers(EntityRenderersEvent.RegisterRenderers event) {
        event.registerBlockEntityRenderer(DecorBlockEntities.DECOR_CONTAINER.get(), DecorContainerRenderer::new);
    }

    @SubscribeEvent
    public static void registerAdditionalModels(ModelEvent.RegisterAdditional event) {
        for (DecorDefinition definition : DecorDefinitionRegistry.all()) {
            BobbleheadRenderDefinition bobblehead = definition.bobbleheadRender();
            if (bobblehead != null) {
                event.register(ModelResourceLocation.standalone(bobblehead.bodyModel()));
                event.register(ModelResourceLocation.standalone(bobblehead.movingModel()));
            }
        }
    }
}
'@

Write-Utf8NoBom 'src/main/java/net/droingo/decor/registry/DecorCreativeTabs.java' @'
package net.droingo.decor.registry;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.api.DecorDefinition;
import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.CreativeModeTab;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforge.registries.DeferredHolder;
import net.neoforged.neoforge.registries.DeferredRegister;

public final class DecorCreativeTabs {
    public static final DeferredRegister<CreativeModeTab> TABS =
            DeferredRegister.create(Registries.CREATIVE_MODE_TAB, DroingosDecor.MOD_ID);

    public static final DeferredHolder<CreativeModeTab, CreativeModeTab> MAIN = TABS.register(
            "main",
            () -> CreativeModeTab.builder()
                    .title(Component.translatable("itemGroup.droingos_decor.main"))
                    .icon(() -> DecorItems.BOBBLE_PARROT.get().getDefaultInstance())
                    .displayItems((parameters, output) -> {
                        for (DecorDefinition definition : DecorDefinitionRegistry.creativeOrder()) {
                            output.accept(definition.pickupStack());
                        }
                    })
                    .build()
    );

    private DecorCreativeTabs() {
    }

    public static void register(IEventBus bus) {
        TABS.register(bus);
    }
}
'@

Write-Utf8NoBom 'src/main/java/net/droingo/decor/DroingosDecor.java' @'
package net.droingo.decor;

import com.mojang.logging.LogUtils;
import net.droingo.decor.compat.sable.SableCompat;
import net.droingo.decor.registry.DecorBlockEntities;
import net.droingo.decor.registry.DecorBlocks;
import net.droingo.decor.registry.DecorCreativeTabs;
import net.droingo.decor.registry.DecorDefinitionRegistry;
import net.droingo.decor.registry.DecorItems;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.ModList;
import net.neoforged.fml.common.Mod;
import org.slf4j.Logger;

@Mod(DroingosDecor.MOD_ID)
public final class DroingosDecor {
    public static final String MOD_ID = "droingos_decor";
    public static final Logger LOGGER = LogUtils.getLogger();

    public DroingosDecor(IEventBus modBus) {
        DecorBlocks.register(modBus);
        DecorItems.register(modBus);
        DecorBlockEntities.register(modBus);
        DecorDefinitionRegistry.bootstrap();
        DecorCreativeTabs.register(modBus);

        if (ModList.get().isLoaded("sable")) {
            SableCompat.init();
        }

        LOGGER.info("Droingo's Decor loaded.");
    }
}
'@

Write-Utf8NoBom 'src/main/resources/assets/droingos_decor/lang/en_us.json' @'
{
  "item.droingos_decor.bobble_parrot": "Bobblehead Parrot",
  "block.droingos_decor.decor_container": "Decor Container",
  "itemGroup.droingos_decor.main": "Droingo's Decor",
  "itemGroup.droingos_decor.category.bobbleheads": "Bobbleheads",
  "itemGroup.droingos_decor.category.wall_decor": "Wall Decor",
  "itemGroup.droingos_decor.category.hanging_decor": "Hanging Decor",
  "itemGroup.droingos_decor.category.small_decor": "Small Decor",
  "itemGroup.droingos_decor.category.furniture": "Furniture",
  "itemGroup.droingos_decor.category.lighting": "Lighting",
  "itemGroup.droingos_decor.category.outdoor_decor": "Outdoor Decor"
}
'@

$oldBackup = Join-Path $root 'src\main\java\net\droingo\decor\client\animation\BobbleheadMotionState.java.bak_20260717_121616'
if (Test-Path -LiteralPath $oldBackup) { Remove-Item -LiteralPath $oldBackup -Force }
Write-Host ""
Write-Host "Decor foundation refactored."
Write-Host "Backup: $backupRoot"
Write-Host ""
Write-Host "Building..."
& .\gradlew.bat build
if ($LASTEXITCODE -ne 0) { throw "Build failed. Original files are backed up at $backupRoot" }
Write-Host "Build successful."
