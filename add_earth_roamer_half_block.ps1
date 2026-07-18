$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Root = (Get-Location).Path
$BackupRoot = Join-Path $Root (".earth_roamer_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))

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

function Replace-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$OldText,
        [Parameter(Mandatory = $true)][string]$NewText,
        [Parameter(Mandatory = $true)][string]$Description
    )
    $Target = Join-Path $Root $RelativePath
    if (!(Test-Path -LiteralPath $Target)) { throw "Missing file: $RelativePath" }
    $Text = [System.IO.File]::ReadAllText($Target)
    if (!$Text.Contains($OldText)) { throw "Could not find expected code for: $Description" }
    Backup-File $RelativePath
    $Text = $Text.Replace($OldText, $NewText)
    [System.IO.File]::WriteAllText($Target, $Text, $Utf8NoBom)
}

if (!(Test-Path -LiteralPath (Join-Path $Root "build.gradle"))) {
    throw "Run this script from the Droingo's Decor project root."
}

# ---------------------------------------------------------------------------
# New half-block toy container
# ---------------------------------------------------------------------------

Write-Utf8NoBom "src/main/java/net/droingo/decor/content/HalfDecorBlock.java" @'
package net.droingo.decor.content;

import com.mojang.serialization.MapCodec;
import net.droingo.decor.registry.DecorItems;
import net.minecraft.core.BlockPos;
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

public final class HalfDecorBlock extends BaseEntityBlock {
    public static final MapCodec<HalfDecorBlock> CODEC =
            simpleCodec(HalfDecorBlock::new);

    private static final VoxelShape SHAPE =
            Shapes.box(0.125D, 0.0D, 0.0625D, 0.875D, 0.4375D, 0.9375D);

    public HalfDecorBlock(Properties properties) {
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
        return new HalfDecorBlockEntity(pos, state);
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
        return SHAPE;
    }

    @Override
    protected InteractionResult useWithoutItem(
            BlockState state,
            Level level,
            BlockPos pos,
            Player player,
            BlockHitResult hit
    ) {
        if (!(level.getBlockEntity(pos) instanceof HalfDecorBlockEntity blockEntity)) {
            return InteractionResult.PASS;
        }

        if (player.isShiftKeyDown()) {
            if (!level.isClientSide) {
                blockEntity.rotate();
            }
        } else if (!level.isClientSide) {
            blockEntity.startPlayAnimation();
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

        HitResult picked = player.pick(5.0D, 1.0F, false);

        if (
                !(picked instanceof BlockHitResult blockHit)
                        || !blockHit.getBlockPos().equals(pos)
        ) {
            return;
        }

        if (!player.getAbilities().instabuild) {
            ItemStack stack =
                    DecorItems.EARTH_ROAMER.get().getDefaultInstance();

            if (!player.getInventory().add(stack)) {
                popResource(level, pos, stack);
            }
        }

        level.removeBlock(pos, false);
    }
}
'@

Write-Utf8NoBom "src/main/java/net/droingo/decor/content/HalfDecorBlockEntity.java" @'
package net.droingo.decor.content;

import net.droingo.decor.registry.DecorBlockEntities;
import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.Connection;
import net.minecraft.network.protocol.game.ClientboundBlockEntityDataPacket;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;

public final class HalfDecorBlockEntity extends BlockEntity {
    private byte rotation;
    private long animationStartTick = Long.MIN_VALUE;

    public HalfDecorBlockEntity(BlockPos pos, BlockState state) {
        super(
                DecorBlockEntities.HALF_DECOR_CONTAINER.get(),
                pos,
                state
        );
    }

    public int getRotation() {
        return Byte.toUnsignedInt(rotation);
    }

    public long getAnimationStartTick() {
        return animationStartTick;
    }

    public void rotate() {
        rotation = (byte) ((rotation + 1) & 15);
        sync();
    }

    public void startPlayAnimation() {
        if (level == null) {
            return;
        }

        animationStartTick = level.getGameTime();
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
        tag.putByte("Rotation", rotation);
        tag.putLong("AnimationStart", animationStartTick);
    }

    @Override
    protected void loadAdditional(
            CompoundTag tag,
            HolderLookup.Provider registries
    ) {
        super.loadAdditional(tag, registries);
        rotation = tag.getByte("Rotation");
        animationStartTick = tag.contains("AnimationStart")
                ? tag.getLong("AnimationStart")
                : Long.MIN_VALUE;
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

    @Override
    public void onDataPacket(
            Connection net,
            ClientboundBlockEntityDataPacket packet,
            HolderLookup.Provider registries
    ) {
        super.onDataPacket(net, packet, registries);
    }
}
'@

Write-Utf8NoBom "src/main/java/net/droingo/decor/content/HalfDecorItem.java" @'
package net.droingo.decor.content;

import net.droingo.decor.registry.DecorBlocks;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.util.Mth;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.context.UseOnContext;
import net.minecraft.world.level.Level;

public final class HalfDecorItem extends Item {
    public HalfDecorItem(Properties properties) {
        super(properties);
    }

    @Override
    public InteractionResult useOn(UseOnContext context) {
        if (context.getClickedFace() != Direction.UP) {
            return InteractionResult.PASS;
        }

        Level level = context.getLevel();
        BlockPos pos = context.getClickedPos().above();

        if (!level.getBlockState(pos).canBeReplaced()) {
            return InteractionResult.FAIL;
        }

        if (!level.isClientSide) {
            level.setBlock(
                    pos,
                    DecorBlocks.HALF_DECOR_CONTAINER
                            .get()
                            .defaultBlockState(),
                    3
            );

            if (
                    level.getBlockEntity(pos)
                            instanceof HalfDecorBlockEntity blockEntity
            ) {
                int desiredRotation =
                        Mth.floor(
                                (context.getRotation() + 11.25F)
                                        / 22.5F
                        ) & 15;

                while (
                        blockEntity.getRotation()
                                != desiredRotation
                ) {
                    blockEntity.rotate();
                }
            }

            if (
                    context.getPlayer() == null
                            || !context.getPlayer()
                            .getAbilities()
                            .instabuild
            ) {
                context.getItemInHand().shrink(1);
            }
        }

        return InteractionResult.sidedSuccess(level.isClientSide);
    }
}
'@

# ---------------------------------------------------------------------------
# Renderer with body translation and wheel rolling
# ---------------------------------------------------------------------------

Write-Utf8NoBom "src/main/java/net/droingo/decor/client/render/HalfDecorRenderer.java" @'
package net.droingo.decor.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;
import net.droingo.decor.DroingosDecor;
import net.droingo.decor.content.HalfDecorBlockEntity;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.block.BlockRenderDispatcher;
import net.minecraft.client.renderer.blockentity.BlockEntityRenderer;
import net.minecraft.client.renderer.blockentity.BlockEntityRendererProvider;
import net.minecraft.client.resources.model.BakedModel;
import net.minecraft.client.resources.model.ModelResourceLocation;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.block.Blocks;
import net.neoforged.neoforge.client.model.data.ModelData;

public final class HalfDecorRenderer
        implements BlockEntityRenderer<HalfDecorBlockEntity> {

    private static final ResourceLocation BODY_MODEL =
            model("earth_roamer_body");

    private static final ResourceLocation FRONT_WHEELS_MODEL =
            model("earth_roamer_front_wheels");

    private static final ResourceLocation REAR_WHEELS_MODEL =
            model("earth_roamer_rear_wheels");

    private static final double ANIMATION_LENGTH_TICKS = 18.0D;
    private static final double MAX_TRAVEL = 2.2D / 16.0D;
    private static final double WHEEL_RADIUS = 1.5D / 16.0D;

    private final BlockRenderDispatcher blockRenderer;

    public HalfDecorRenderer(
            BlockEntityRendererProvider.Context context
    ) {
        blockRenderer = context.getBlockRenderDispatcher();
    }

    @Override
    public void render(
            HalfDecorBlockEntity blockEntity,
            float partialTick,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        float yawDegrees =
                blockEntity.getRotation() * 22.5F;

        double progress = animationProgress(
                blockEntity,
                partialTick
        );

        double travel = travelAt(progress);
        double wheelDegrees =
                Math.toDegrees(travel / WHEEL_RADIUS);

        poseStack.pushPose();

        poseStack.translate(0.5D, 0.03125D, 0.5D);
        poseStack.mulPose(
                Axis.YP.rotationDegrees(yawDegrees)
        );

        /*
         * The model's front is local -Z, so positive play travel is -Z.
         */
        poseStack.translate(
                -0.5D,
                0.0D,
                -0.5D - travel
        );

        renderModel(
                poseStack,
                buffers,
                BODY_MODEL,
                packedLight,
                packedOverlay
        );

        renderWheels(
                poseStack,
                buffers,
                FRONT_WHEELS_MODEL,
                8.0D / 16.0D,
                1.5D / 16.0D,
                3.5D / 16.0D,
                wheelDegrees,
                packedLight,
                packedOverlay
        );

        renderWheels(
                poseStack,
                buffers,
                REAR_WHEELS_MODEL,
                8.0D / 16.0D,
                1.5D / 16.0D,
                10.5D / 16.0D,
                wheelDegrees,
                packedLight,
                packedOverlay
        );

        poseStack.popPose();
    }

    private static double animationProgress(
            HalfDecorBlockEntity blockEntity,
            float partialTick
    ) {
        if (
                blockEntity.getLevel() == null
                        || blockEntity.getAnimationStartTick()
                        == Long.MIN_VALUE
        ) {
            return 1.0D;
        }

        double elapsed =
                blockEntity.getLevel().getGameTime()
                        + partialTick
                        - blockEntity.getAnimationStartTick();

        return Math.max(
                0.0D,
                Math.min(
                        1.0D,
                        elapsed / ANIMATION_LENGTH_TICKS
                )
        );
    }

    private static double travelAt(double progress) {
        if (progress >= 1.0D) {
            return 0.0D;
        }

        /*
         * A smooth forward push followed by a smooth pull back.
         * sin(pi * progress) guarantees exact rest at both ends.
         */
        return Math.sin(Math.PI * progress)
                * MAX_TRAVEL;
    }

    private void renderWheels(
            PoseStack poseStack,
            MultiBufferSource buffers,
            ResourceLocation model,
            double pivotX,
            double pivotY,
            double pivotZ,
            double wheelDegrees,
            int packedLight,
            int packedOverlay
    ) {
        poseStack.pushPose();
        poseStack.translate(pivotX, pivotY, pivotZ);

        /*
         * Wheel axles run across X, so rolling is rotation around X.
         */
        poseStack.mulPose(
                Axis.XP.rotationDegrees(
                        (float) -wheelDegrees
                )
        );

        poseStack.translate(-pivotX, -pivotY, -pivotZ);

        renderModel(
                poseStack,
                buffers,
                model,
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
        BakedModel model =
                Minecraft.getInstance()
                        .getModelManager()
                        .getModel(
                                ModelResourceLocation.standalone(
                                        location
                                )
                        );

        VertexConsumer consumer =
                buffers.getBuffer(RenderType.cutout());

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

    private static ResourceLocation model(String name) {
        return ResourceLocation.fromNamespaceAndPath(
                DroingosDecor.MOD_ID,
                "block/" + name
        );
    }
}
'@

# ---------------------------------------------------------------------------
# Registry changes
# ---------------------------------------------------------------------------

Replace-Checked "src/main/java/net/droingo/decor/registry/DecorBlocks.java" @'
import net.droingo.decor.content.DecorContainerBlock;
import net.droingo.decor.content.WallDecorBlock;
'@ @'
import net.droingo.decor.content.DecorContainerBlock;
import net.droingo.decor.content.HalfDecorBlock;
import net.droingo.decor.content.WallDecorBlock;
'@ "HalfDecorBlock import"

Replace-Checked "src/main/java/net/droingo/decor/registry/DecorBlocks.java" @'
    public static final DeferredBlock<WallDecorBlock> WALL_DECOR_CONTAINER =
'@ @'
    public static final DeferredBlock<HalfDecorBlock> HALF_DECOR_CONTAINER =
            BLOCKS.registerBlock(
                    "half_decor_container",
                    HalfDecorBlock::new,
                    BlockBehaviour.Properties.of()
                            .mapColor(MapColor.NONE)
                            .strength(0.2F)
                            .sound(SoundType.WOOD)
                            .noOcclusion()
                            .noCollission()
            );

    public static final DeferredBlock<WallDecorBlock> WALL_DECOR_CONTAINER =
'@ "half decor block registration"

Replace-Checked "src/main/java/net/droingo/decor/registry/DecorBlockEntities.java" @'
import net.droingo.decor.content.DecorContainerBlockEntity;
import net.droingo.decor.content.WallDecorBlockEntity;
'@ @'
import net.droingo.decor.content.DecorContainerBlockEntity;
import net.droingo.decor.content.HalfDecorBlockEntity;
import net.droingo.decor.content.WallDecorBlockEntity;
'@ "HalfDecorBlockEntity import"

Replace-Checked "src/main/java/net/droingo/decor/registry/DecorBlockEntities.java" @'
    public static final DeferredHolder<
            BlockEntityType<?>,
            BlockEntityType<WallDecorBlockEntity>
'@ @'
    public static final DeferredHolder<
            BlockEntityType<?>,
            BlockEntityType<HalfDecorBlockEntity>
            > HALF_DECOR_CONTAINER = TYPES.register(
            "half_decor_container",
            () -> BlockEntityType.Builder.of(
                    HalfDecorBlockEntity::new,
                    DecorBlocks.HALF_DECOR_CONTAINER.get()
            ).build(null)
    );

    public static final DeferredHolder<
            BlockEntityType<?>,
            BlockEntityType<WallDecorBlockEntity>
'@ "half decor block entity registration"

Replace-Checked "src/main/java/net/droingo/decor/registry/DecorItems.java" @'
import net.droingo.decor.content.TinyDecorItem;
import net.droingo.decor.content.WallDecorItem;
'@ @'
import net.droingo.decor.content.HalfDecorItem;
import net.droingo.decor.content.TinyDecorItem;
import net.droingo.decor.content.WallDecorItem;
'@ "HalfDecorItem import"

Replace-Checked "src/main/java/net/droingo/decor/registry/DecorItems.java" @'
    public static final DeferredItem<Item> BOBBLE_PARROT = ITEMS.register(
'@ @'
    public static final DeferredItem<Item> EARTH_ROAMER = ITEMS.register(
            "earth_roamer",
            () -> new HalfDecorItem(new Item.Properties())
    );

    public static final DeferredItem<Item> BOBBLE_PARROT = ITEMS.register(
'@ "Earth Roamer item registration"

Replace-Checked "src/main/java/net/droingo/decor/registry/DecorItems.java" @'
    public static final List<DeferredItem<Item>> WALL_DECOR_HEADER =
'@ @'
    public static final List<DeferredItem<Item>> HALF_BLOCKS_HEADER =
            registerHeader("half_blocks");

    public static final List<DeferredItem<Item>> WALL_DECOR_HEADER =
'@ "Half Blocks creative header"

Replace-Checked "src/main/java/net/droingo/decor/registry/DecorItems.java" @'
            case BOBBLEHEADS -> BOBBLEHEAD_HEADER;
            case WALL_DECOR -> WALL_DECOR_HEADER;
'@ @'
            case BOBBLEHEADS -> BOBBLEHEAD_HEADER;
            case HALF_BLOCKS -> HALF_BLOCKS_HEADER;
            case WALL_DECOR -> WALL_DECOR_HEADER;
'@ "Half Blocks creative header switch"

Replace-Checked "src/main/java/net/droingo/decor/api/DecorCategory.java" @'
    BOBBLEHEADS("bobbleheads", 0),
    WALL_DECOR("wall_decor", 10),
'@ @'
    BOBBLEHEADS("bobbleheads", 0),
    HALF_BLOCKS("half_blocks", 5),
    WALL_DECOR("wall_decor", 10),
'@ "Half Blocks category"

Replace-Checked "src/main/java/net/droingo/decor/api/DecorPlacementType.java" @'
    TINY,
    SMALL,
'@ @'
    TINY,
    HALF_BLOCK,
    SMALL,
'@ "half-block placement type"

Replace-Checked "src/main/java/net/droingo/decor/registry/DecorDefinitionRegistry.java" @'
        ResourceLocation sweaterId = id("hanging_sweater");
'@ @'
        ResourceLocation earthRoamerId = id("earth_roamer");

        register(
                DecorDefinition.builder(earthRoamerId)
                        .category(DecorCategory.HALF_BLOCKS)
                        .placement(DecorPlacementType.HALF_BLOCK)
                        .item(DecorItems.EARTH_ROAMER::get)
                        .bounds(
                                -0.375D,
                                0.0D,
                                -0.4375D,
                                0.375D,
                                0.4375D,
                                0.4375D
                        )
                        .build()
        );

        ResourceLocation sweaterId = id("hanging_sweater");
'@ "Earth Roamer decor definition"

Replace-Checked "src/main/java/net/droingo/decor/client/creative/CreativeCategoryScreenEvents.java" @'
        labels.put(
                "wall_decor",
'@ @'
        labels.put(
                "half_blocks",
                Component.literal("Half Blocks")
        );

        labels.put(
                "wall_decor",
'@ "Half Blocks banner label"

Replace-Checked "src/main/java/net/droingo/decor/client/DroingosDecorClient.java" @'
import net.droingo.decor.client.render.DecorContainerRenderer;
import net.droingo.decor.client.render.WallDecorRenderer;
'@ @'
import net.droingo.decor.client.render.DecorContainerRenderer;
import net.droingo.decor.client.render.HalfDecorRenderer;
import net.droingo.decor.client.render.WallDecorRenderer;
'@ "HalfDecorRenderer import"

Replace-Checked "src/main/java/net/droingo/decor/client/DroingosDecorClient.java" @'
        event.registerBlockEntityRenderer(
                DecorBlockEntities.WALL_DECOR_CONTAINER.get(),
'@ @'
        event.registerBlockEntityRenderer(
                DecorBlockEntities.HALF_DECOR_CONTAINER.get(),
                HalfDecorRenderer::new
        );

        event.registerBlockEntityRenderer(
                DecorBlockEntities.WALL_DECOR_CONTAINER.get(),
'@ "half decor renderer registration"

Replace-Checked "src/main/java/net/droingo/decor/client/DroingosDecorClient.java" @'
    public static void registerAdditionalModels(
            ModelEvent.RegisterAdditional event
    ) {
'@ @'
    public static void registerAdditionalModels(
            ModelEvent.RegisterAdditional event
    ) {
        event.register(
                ModelResourceLocation.standalone(
                        net.minecraft.resources.ResourceLocation
                                .fromNamespaceAndPath(
                                        DroingosDecor.MOD_ID,
                                        "block/earth_roamer_body"
                                )
                )
        );

        event.register(
                ModelResourceLocation.standalone(
                        net.minecraft.resources.ResourceLocation
                                .fromNamespaceAndPath(
                                        DroingosDecor.MOD_ID,
                                        "block/earth_roamer_front_wheels"
                                )
                )
        );

        event.register(
                ModelResourceLocation.standalone(
                        net.minecraft.resources.ResourceLocation
                                .fromNamespaceAndPath(
                                        DroingosDecor.MOD_ID,
                                        "block/earth_roamer_rear_wheels"
                                )
                )
        );

'@ "Earth Roamer model registration"

# ---------------------------------------------------------------------------
# Resources
# ---------------------------------------------------------------------------

Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/block/earth_roamer_body.json" @'
{
  "parent": "block/block",
  "texture_size": [
    32,
    32
  ],
  "textures": {
    "0": "droingos_decor:block/earth_roamer",
    "particle": "droingos_decor:block/earth_roamer"
  },
  "elements": [
    {
      "from": [
        6.5,
        2.5,
        1.5
      ],
      "to": [
        9.5,
        3,
        2.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          1.5,
          1.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            11.5,
            13.5,
            12.5,
            13.75
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            14,
            14,
            14.5,
            14.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            12.5,
            13.5,
            13.5,
            13.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            14.5,
            0.5,
            14.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            11.5,
            13,
            10.5,
            12.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            13.5,
            11,
            12.5,
            11.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        5.8,
        1,
        3
      ],
      "to": [
        10.3,
        2,
        4
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          0,
          3
        ]
      },
      "faces": {
        "north": {
          "uv": [
            11,
            2.5,
            13,
            3
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0.5,
            13,
            1,
            13.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            4.5,
            11,
            6.5,
            11.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            7,
            13,
            7.5,
            13.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            13,
            6,
            11,
            5.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            13,
            6,
            11,
            6.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        5.7,
        1,
        10
      ],
      "to": [
        10.4,
        2,
        11
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          0,
          10
        ]
      },
      "faces": {
        "north": {
          "uv": [
            6.5,
            11,
            8.5,
            11.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            7.5,
            13.5,
            8,
            14
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            11,
            6.5,
            13,
            7
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            13.5,
            12.5,
            14,
            13
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            3,
            12,
            1,
            11.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            5,
            11.5,
            3,
            12
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        6.5,
        2.5,
        4.5
      ],
      "to": [
        9.5,
        3,
        12.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          1.5,
          2.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            12.5,
            12,
            14,
            12.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            11.5,
            3,
            15.5,
            3.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            1.5,
            13,
            3,
            13.25
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            11.5,
            3.5,
            15.5,
            3.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            5,
            4,
            3.5,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            1.5,
            4,
            0,
            8
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        6,
        2.5,
        2.5
      ],
      "to": [
        10,
        3,
        4.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          1.5,
          2.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            11.5,
            12.5,
            13.5,
            12.75
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            13.5,
            13,
            14.5,
            13.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            12.5,
            11.5,
            14.5,
            11.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            13.5,
            13.5,
            14.5,
            13.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            7,
            4,
            5,
            3
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            10.5,
            4.5,
            8.5,
            5.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        6.5,
        3,
        11.5
      ],
      "to": [
        9.5,
        5,
        12.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          1.5,
          2.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            10.5,
            4.5,
            12,
            5.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            7,
            3,
            7.5,
            4
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            11,
            1.5,
            12.5,
            2.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            8.5,
            7,
            9,
            8
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            13,
            4.5,
            11.5,
            4
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            6.5,
            11.5,
            5,
            12
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        6.5,
        3,
        3.5
      ],
      "to": [
        9.5,
        5.5,
        4.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          1.5,
          -5.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            3,
            8.5,
            4.5,
            9.75
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            12,
            0,
            12.5,
            1.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            8.5,
            5.5,
            10,
            6.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            1,
            12,
            1.5,
            13.25
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            8,
            12,
            6.5,
            11.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            13,
            7,
            11.5,
            7.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        6.5,
        3,
        4
      ],
      "to": [
        9.5,
        6,
        6.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          1.5,
          -3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            7.5,
            8,
            9,
            9.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            9,
            3,
            10.25,
            4.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            1.5,
            8.5,
            3,
            10
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            9,
            7,
            10.25,
            8.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            10.5,
            9.75,
            9,
            8.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            1.5,
            9.5,
            0,
            10.75
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        8,
        3.3,
        1
      ],
      "to": [
        8,
        7.3,
        7.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          1.8,
          -3.5
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
            0,
            0,
            3.25,
            2
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
            0,
            2,
            3.25,
            4
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0,
            3.25,
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
            3.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        6,
        3,
        4
      ],
      "to": [
        10,
        5.5,
        6.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          1.5,
          -3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            4.5,
            5,
            6.5,
            6.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            9.5,
            0,
            10.75,
            1.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            4.5,
            6.5,
            6.5,
            7.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            9.5,
            1.5,
            10.75,
            2.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            8.5,
            6.25,
            6.5,
            5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            8.5,
            6.5,
            6.5,
            7.75
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        7.7,
        5.5,
        10.5
      ],
      "to": [
        7.7,
        6.5,
        11.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          6.2,
          1.5,
          1.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            0.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            8.5,
            9.5,
            9,
            10
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            0.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            1,
            11,
            1.5,
            11.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0,
            0.5,
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
            0.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        8.5,
        5.5,
        10.5
      ],
      "to": [
        8.5,
        6.5,
        11.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.5,
          1.5,
          1.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            0.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0.5,
            14,
            1,
            14.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            0.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            1,
            14,
            1.5,
            14.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0,
            0.5,
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
            0.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        7.9,
        6,
        10.3
      ],
      "to": [
        8.4,
        6.5,
        12.8
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          6.9,
          1.5,
          1.8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            14.5,
            0,
            14.75,
            0.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            13,
            4,
            14.25,
            4.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0.5,
            14.5,
            0.75,
            14.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            4.5,
            13,
            5.75,
            13.25
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            7.75,
            13.25,
            7.5,
            12
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            0.25,
            13,
            0,
            14.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        9.5,
        3,
        6.5
      ],
      "to": [
        10,
        5,
        12
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          1.5,
          2.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            1.5,
            14,
            1.75,
            15
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            4.5,
            4,
            7.25,
            5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            2,
            14,
            2.25,
            15
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            5,
            0,
            7.75,
            1
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            11.75,
            10.25,
            11.5,
            7.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            8.25,
            11.5,
            8,
            14.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        6,
        3,
        6.5
      ],
      "to": [
        6.5,
        5,
        12
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          3.5,
          1.5,
          2.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            2.5,
            14,
            2.75,
            15
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            5,
            1,
            7.75,
            2
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            3,
            14,
            3.25,
            15
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            5,
            2,
            7.75,
            3
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            8.75,
            14.25,
            8.5,
            11.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            9.25,
            11.5,
            9,
            14.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        6.5,
        5,
        6.5
      ],
      "to": [
        9.5,
        5.5,
        12
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          1,
          2.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            13,
            2.5,
            14.5,
            2.75
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            9.5,
            11.5,
            12.25,
            11.75
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            3,
            13,
            4.5,
            13.25
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            11.5,
            10.5,
            14.25,
            10.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            3,
            6.75,
            1.5,
            4
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            4.5,
            4,
            3,
            6.75
          ],
          "texture": "#0"
        }
      }
    }
  ]
}
'@

Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/block/earth_roamer_front_wheels.json" @'
{
  "parent": "block/block",
  "texture_size": [
    32,
    32
  ],
  "textures": {
    "0": "droingos_decor:block/earth_roamer",
    "particle": "droingos_decor:block/earth_roamer"
  },
  "elements": [
    {
      "from": [
        10.2,
        0,
        2
      ],
      "to": [
        11.8,
        3,
        5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          10,
          1.5,
          3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            4.5,
            9.5,
            5.5,
            11
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            1.5,
            7,
            3,
            8.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            5.5,
            9.5,
            6.5,
            11
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            3,
            7,
            4.5,
            8.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            7.5,
            11,
            6.5,
            9.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            8.5,
            9.5,
            7.5,
            11
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        10.2,
        1,
        1.5
      ],
      "to": [
        11.8,
        2,
        2
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          10,
          1.5,
          3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            7.5,
            4.5,
            8.5,
            5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            3.5,
            14,
            3.75,
            14.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            11.5,
            11,
            12.5,
            11.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            4,
            14,
            4.25,
            14.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            14,
            4.75,
            13,
            4.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            14,
            5,
            13,
            5.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        10.2,
        1,
        5
      ],
      "to": [
        11.8,
        2,
        5.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          10,
          1.5,
          3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            1.5,
            12,
            2.5,
            12.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            4.5,
            14,
            4.75,
            14.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            2.5,
            12,
            3.5,
            12.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            14,
            4.5,
            14.25,
            5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            14,
            5.75,
            13,
            5.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            7,
            13,
            6,
            13.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        10.2,
        3,
        3
      ],
      "to": [
        11.8,
        3.5,
        4
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          10,
          1.5,
          3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            13,
            6,
            14,
            6.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            5,
            14,
            5.5,
            14.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            13,
            6.5,
            14,
            6.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            14,
            5,
            14.5,
            5.25
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            4.5,
            12.5,
            3.5,
            12
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            5.5,
            12,
            4.5,
            12.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        10.2,
        -0.5,
        3
      ],
      "to": [
        11.8,
        0,
        4
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          10,
          1.5,
          3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            13,
            7,
            14,
            7.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            5.5,
            14,
            6,
            14.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            13,
            7.5,
            14,
            7.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            14,
            5.5,
            14.5,
            5.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            13,
            5,
            12,
            4.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            13,
            5,
            12,
            5.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.2,
        0,
        2
      ],
      "to": [
        5.8,
        3,
        5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          4,
          1.5,
          3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            1.5,
            10,
            2.5,
            11.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            7.5,
            3,
            9,
            4.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            2.5,
            10,
            3.5,
            11.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            8,
            1.5,
            9.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            4.5,
            11.5,
            3.5,
            10
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            11,
            5.5,
            10,
            7
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.2,
        1,
        1.5
      ],
      "to": [
        5.8,
        2,
        2
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          4,
          1.5,
          3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            5.5,
            12,
            6.5,
            12.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            6,
            14,
            6.25,
            14.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            6.5,
            12,
            7.5,
            12.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            14,
            6,
            14.25,
            6.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            14,
            8.25,
            13,
            8
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            14,
            8.5,
            13,
            8.75
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.2,
        1,
        5
      ],
      "to": [
        5.8,
        2,
        5.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          4,
          1.5,
          3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            12,
            7.5,
            13,
            8
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            6.5,
            14,
            6.75,
            14.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            12,
            8,
            13,
            8.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            14,
            6.5,
            14.25,
            7
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            14,
            9.25,
            13,
            9
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            10.5,
            13,
            9.5,
            13.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.2,
        3,
        3
      ],
      "to": [
        5.8,
        3.5,
        4
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          4,
          1.5,
          3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            13,
            9.5,
            14,
            9.75
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            7,
            14,
            7.5,
            14.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            13,
            10,
            14,
            10.25
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            14,
            7,
            14.5,
            7.25
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            13,
            9,
            12,
            8.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            13,
            9,
            12,
            9.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.2,
        -0.5,
        3
      ],
      "to": [
        5.8,
        0,
        4
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          4,
          1.5,
          3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            10.5,
            13,
            11.5,
            13.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            7.5,
            14,
            8,
            14.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            11.5,
            13,
            12.5,
            13.25
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            14,
            7.5,
            14.5,
            7.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            10.5,
            12.5,
            9.5,
            12
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            13,
            9.5,
            12,
            10
          ],
          "texture": "#0"
        }
      }
    }
  ]
}
'@

Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/block/earth_roamer_rear_wheels.json" @'
{
  "parent": "block/block",
  "texture_size": [
    32,
    32
  ],
  "textures": {
    "0": "droingos_decor:block/earth_roamer",
    "particle": "droingos_decor:block/earth_roamer"
  },
  "elements": [
    {
      "from": [
        10.2,
        0,
        9
      ],
      "to": [
        11.8,
        3,
        12
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          10,
          1.5,
          10.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            8.5,
            10,
            9.5,
            11.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            8,
            0,
            9.5,
            1.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            9.5,
            10,
            10.5,
            11.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            8,
            1.5,
            9.5,
            3
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            11.5,
            4.5,
            10.5,
            3
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            11.5,
            7,
            10.5,
            8.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        10.2,
        1,
        8.5
      ],
      "to": [
        11.8,
        2,
        9
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          10,
          1.5,
          10.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            12,
            10,
            13,
            10.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            14,
            8,
            14.25,
            8.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            10.5,
            12,
            11.5,
            12.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            14,
            8.5,
            14.25,
            9
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            13.5,
            13.25,
            12.5,
            13
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            14.5,
            0,
            13.5,
            0.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        10.2,
        1,
        12
      ],
      "to": [
        11.8,
        2,
        12.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          10,
          1.5,
          10.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            11.5,
            12,
            12.5,
            12.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            14,
            9,
            14.25,
            9.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            12.5,
            1,
            13
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            9.5,
            14,
            9.75,
            14.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            1.5,
            13.75,
            0.5,
            13.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            14.5,
            0.5,
            13.5,
            0.75
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        10.2,
        3,
        10
      ],
      "to": [
        11.8,
        3.5,
        11
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          10,
          1.5,
          10.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            13.5,
            1,
            14.5,
            1.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            14,
            9.5,
            14.5,
            9.75
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            1.5,
            13.5,
            2.5,
            13.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            10,
            14,
            10.5,
            14.25
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            13.5,
            0.5,
            12.5,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            13.5,
            0.5,
            12.5,
            1
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        10.2,
        -0.5,
        10
      ],
      "to": [
        11.8,
        0,
        11
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          10,
          1.5,
          10.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            13.5,
            1.5,
            14.5,
            1.75
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            14,
            10,
            14.5,
            10.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            13.5,
            2,
            14.5,
            2.25
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            10.5,
            14,
            11,
            14.25
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            13.5,
            1.5,
            12.5,
            1
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            2.5,
            12.5,
            1.5,
            13
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.2,
        0,
        9
      ],
      "to": [
        5.8,
        3,
        12
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          4,
          1.5,
          10.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            10.5,
            8.5,
            11.5,
            10
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            4.5,
            8,
            6,
            9.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            10.5,
            10,
            11.5,
            11.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            6,
            8,
            7.5,
            9.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            1,
            12.5,
            0,
            11
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            12,
            0,
            11,
            1.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.2,
        1,
        8.5
      ],
      "to": [
        5.8,
        2,
        9
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          4,
          1.5,
          10.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            12.5,
            1.5,
            13.5,
            2
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            11,
            14,
            11.25,
            14.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            12.5,
            2,
            13.5,
            2.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            11.5,
            14,
            11.75,
            14.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            3.5,
            13.75,
            2.5,
            13.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            4.5,
            13.5,
            3.5,
            13.75
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.2,
        1,
        12
      ],
      "to": [
        5.8,
        2,
        12.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          4,
          1.5,
          10.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            2.5,
            12.5,
            3.5,
            13
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            12,
            14,
            12.25,
            14.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            3.5,
            12.5,
            4.5,
            13
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            14,
            12,
            14.25,
            12.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            5.5,
            13.75,
            4.5,
            13.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            6.5,
            13.5,
            5.5,
            13.75
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.2,
        3,
        10
      ],
      "to": [
        5.8,
        3.5,
        11
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          4,
          1.5,
          10.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            6.5,
            13.5,
            7.5,
            13.75
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            12.5,
            14,
            13,
            14.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            9.5,
            13.5,
            10.5,
            13.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            14,
            12.5,
            14.5,
            12.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            5.5,
            13,
            4.5,
            12.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            6.5,
            12.5,
            5.5,
            13
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.2,
        -0.5,
        10
      ],
      "to": [
        5.8,
        0,
        11
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          4,
          1.5,
          10.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            10.5,
            13.5,
            11.5,
            13.75
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            13,
            14,
            13.5,
            14.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            13.5,
            11,
            14.5,
            11.25
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            13.5,
            14,
            14,
            14.25
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            7.5,
            13,
            6.5,
            12.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            10.5,
            12.5,
            9.5,
            13
          ],
          "texture": "#0"
        }
      }
    }
  ]
}
'@

Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/earth_roamer.json" @'
{
  "texture_size": [
    32,
    32
  ],
  "textures": {
    "0": "droingos_decor:block/earth_roamer",
    "particle": "droingos_decor:block/earth_roamer"
  },
  "elements": [
    {
      "from": [
        10.2,
        0,
        2
      ],
      "to": [
        11.8,
        3,
        5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          10,
          1.5,
          3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            4.5,
            9.5,
            5.5,
            11
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            1.5,
            7,
            3,
            8.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            5.5,
            9.5,
            6.5,
            11
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            3,
            7,
            4.5,
            8.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            7.5,
            11,
            6.5,
            9.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            8.5,
            9.5,
            7.5,
            11
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        10.2,
        1,
        1.5
      ],
      "to": [
        11.8,
        2,
        2
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          10,
          1.5,
          3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            7.5,
            4.5,
            8.5,
            5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            3.5,
            14,
            3.75,
            14.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            11.5,
            11,
            12.5,
            11.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            4,
            14,
            4.25,
            14.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            14,
            4.75,
            13,
            4.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            14,
            5,
            13,
            5.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        10.2,
        1,
        5
      ],
      "to": [
        11.8,
        2,
        5.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          10,
          1.5,
          3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            1.5,
            12,
            2.5,
            12.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            4.5,
            14,
            4.75,
            14.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            2.5,
            12,
            3.5,
            12.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            14,
            4.5,
            14.25,
            5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            14,
            5.75,
            13,
            5.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            7,
            13,
            6,
            13.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        10.2,
        3,
        3
      ],
      "to": [
        11.8,
        3.5,
        4
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          10,
          1.5,
          3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            13,
            6,
            14,
            6.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            5,
            14,
            5.5,
            14.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            13,
            6.5,
            14,
            6.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            14,
            5,
            14.5,
            5.25
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            4.5,
            12.5,
            3.5,
            12
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            5.5,
            12,
            4.5,
            12.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        10.2,
        -0.5,
        3
      ],
      "to": [
        11.8,
        0,
        4
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          10,
          1.5,
          3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            13,
            7,
            14,
            7.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            5.5,
            14,
            6,
            14.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            13,
            7.5,
            14,
            7.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            14,
            5.5,
            14.5,
            5.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            13,
            5,
            12,
            4.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            13,
            5,
            12,
            5.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.2,
        0,
        2
      ],
      "to": [
        5.8,
        3,
        5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          4,
          1.5,
          3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            1.5,
            10,
            2.5,
            11.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            7.5,
            3,
            9,
            4.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            2.5,
            10,
            3.5,
            11.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            8,
            1.5,
            9.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            4.5,
            11.5,
            3.5,
            10
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            11,
            5.5,
            10,
            7
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.2,
        1,
        1.5
      ],
      "to": [
        5.8,
        2,
        2
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          4,
          1.5,
          3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            5.5,
            12,
            6.5,
            12.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            6,
            14,
            6.25,
            14.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            6.5,
            12,
            7.5,
            12.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            14,
            6,
            14.25,
            6.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            14,
            8.25,
            13,
            8
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            14,
            8.5,
            13,
            8.75
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.2,
        1,
        5
      ],
      "to": [
        5.8,
        2,
        5.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          4,
          1.5,
          3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            12,
            7.5,
            13,
            8
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            6.5,
            14,
            6.75,
            14.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            12,
            8,
            13,
            8.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            14,
            6.5,
            14.25,
            7
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            14,
            9.25,
            13,
            9
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            10.5,
            13,
            9.5,
            13.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.2,
        3,
        3
      ],
      "to": [
        5.8,
        3.5,
        4
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          4,
          1.5,
          3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            13,
            9.5,
            14,
            9.75
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            7,
            14,
            7.5,
            14.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            13,
            10,
            14,
            10.25
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            14,
            7,
            14.5,
            7.25
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            13,
            9,
            12,
            8.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            13,
            9,
            12,
            9.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.2,
        -0.5,
        3
      ],
      "to": [
        5.8,
        0,
        4
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          4,
          1.5,
          3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            10.5,
            13,
            11.5,
            13.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            7.5,
            14,
            8,
            14.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            11.5,
            13,
            12.5,
            13.25
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            14,
            7.5,
            14.5,
            7.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            10.5,
            12.5,
            9.5,
            12
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            13,
            9.5,
            12,
            10
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        10.2,
        0,
        9
      ],
      "to": [
        11.8,
        3,
        12
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          10,
          1.5,
          10.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            8.5,
            10,
            9.5,
            11.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            8,
            0,
            9.5,
            1.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            9.5,
            10,
            10.5,
            11.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            8,
            1.5,
            9.5,
            3
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            11.5,
            4.5,
            10.5,
            3
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            11.5,
            7,
            10.5,
            8.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        10.2,
        1,
        8.5
      ],
      "to": [
        11.8,
        2,
        9
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          10,
          1.5,
          10.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            12,
            10,
            13,
            10.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            14,
            8,
            14.25,
            8.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            10.5,
            12,
            11.5,
            12.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            14,
            8.5,
            14.25,
            9
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            13.5,
            13.25,
            12.5,
            13
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            14.5,
            0,
            13.5,
            0.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        10.2,
        1,
        12
      ],
      "to": [
        11.8,
        2,
        12.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          10,
          1.5,
          10.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            11.5,
            12,
            12.5,
            12.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            14,
            9,
            14.25,
            9.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            12.5,
            1,
            13
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            9.5,
            14,
            9.75,
            14.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            1.5,
            13.75,
            0.5,
            13.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            14.5,
            0.5,
            13.5,
            0.75
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        10.2,
        3,
        10
      ],
      "to": [
        11.8,
        3.5,
        11
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          10,
          1.5,
          10.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            13.5,
            1,
            14.5,
            1.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            14,
            9.5,
            14.5,
            9.75
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            1.5,
            13.5,
            2.5,
            13.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            10,
            14,
            10.5,
            14.25
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            13.5,
            0.5,
            12.5,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            13.5,
            0.5,
            12.5,
            1
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        10.2,
        -0.5,
        10
      ],
      "to": [
        11.8,
        0,
        11
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          10,
          1.5,
          10.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            13.5,
            1.5,
            14.5,
            1.75
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            14,
            10,
            14.5,
            10.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            13.5,
            2,
            14.5,
            2.25
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            10.5,
            14,
            11,
            14.25
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            13.5,
            1.5,
            12.5,
            1
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            2.5,
            12.5,
            1.5,
            13
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.2,
        0,
        9
      ],
      "to": [
        5.8,
        3,
        12
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          4,
          1.5,
          10.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            10.5,
            8.5,
            11.5,
            10
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            4.5,
            8,
            6,
            9.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            10.5,
            10,
            11.5,
            11.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            6,
            8,
            7.5,
            9.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            1,
            12.5,
            0,
            11
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            12,
            0,
            11,
            1.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.2,
        1,
        8.5
      ],
      "to": [
        5.8,
        2,
        9
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          4,
          1.5,
          10.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            12.5,
            1.5,
            13.5,
            2
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            11,
            14,
            11.25,
            14.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            12.5,
            2,
            13.5,
            2.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            11.5,
            14,
            11.75,
            14.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            3.5,
            13.75,
            2.5,
            13.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            4.5,
            13.5,
            3.5,
            13.75
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.2,
        1,
        12
      ],
      "to": [
        5.8,
        2,
        12.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          4,
          1.5,
          10.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            2.5,
            12.5,
            3.5,
            13
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            12,
            14,
            12.25,
            14.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            3.5,
            12.5,
            4.5,
            13
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            14,
            12,
            14.25,
            12.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            5.5,
            13.75,
            4.5,
            13.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            6.5,
            13.5,
            5.5,
            13.75
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.2,
        3,
        10
      ],
      "to": [
        5.8,
        3.5,
        11
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          4,
          1.5,
          10.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            6.5,
            13.5,
            7.5,
            13.75
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            12.5,
            14,
            13,
            14.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            9.5,
            13.5,
            10.5,
            13.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            14,
            12.5,
            14.5,
            12.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            5.5,
            13,
            4.5,
            12.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            6.5,
            12.5,
            5.5,
            13
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        4.2,
        -0.5,
        10
      ],
      "to": [
        5.8,
        0,
        11
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          4,
          1.5,
          10.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            10.5,
            13.5,
            11.5,
            13.75
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            13,
            14,
            13.5,
            14.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            13.5,
            11,
            14.5,
            11.25
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            13.5,
            14,
            14,
            14.25
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            7.5,
            13,
            6.5,
            12.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            10.5,
            12.5,
            9.5,
            13
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        6.5,
        2.5,
        1.5
      ],
      "to": [
        9.5,
        3,
        2.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          1.5,
          1.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            11.5,
            13.5,
            12.5,
            13.75
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            14,
            14,
            14.5,
            14.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            12.5,
            13.5,
            13.5,
            13.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            14.5,
            0.5,
            14.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            11.5,
            13,
            10.5,
            12.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            13.5,
            11,
            12.5,
            11.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        5.8,
        1,
        3
      ],
      "to": [
        10.3,
        2,
        4
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          0,
          3
        ]
      },
      "faces": {
        "north": {
          "uv": [
            11,
            2.5,
            13,
            3
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0.5,
            13,
            1,
            13.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            4.5,
            11,
            6.5,
            11.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            7,
            13,
            7.5,
            13.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            13,
            6,
            11,
            5.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            13,
            6,
            11,
            6.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        5.7,
        1,
        10
      ],
      "to": [
        10.4,
        2,
        11
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          0,
          10
        ]
      },
      "faces": {
        "north": {
          "uv": [
            6.5,
            11,
            8.5,
            11.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            7.5,
            13.5,
            8,
            14
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            11,
            6.5,
            13,
            7
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            13.5,
            12.5,
            14,
            13
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            3,
            12,
            1,
            11.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            5,
            11.5,
            3,
            12
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        6.5,
        2.5,
        4.5
      ],
      "to": [
        9.5,
        3,
        12.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          1.5,
          2.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            12.5,
            12,
            14,
            12.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            11.5,
            3,
            15.5,
            3.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            1.5,
            13,
            3,
            13.25
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            11.5,
            3.5,
            15.5,
            3.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            5,
            4,
            3.5,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            1.5,
            4,
            0,
            8
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        6,
        2.5,
        2.5
      ],
      "to": [
        10,
        3,
        4.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          1.5,
          2.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            11.5,
            12.5,
            13.5,
            12.75
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            13.5,
            13,
            14.5,
            13.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            12.5,
            11.5,
            14.5,
            11.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            13.5,
            13.5,
            14.5,
            13.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            7,
            4,
            5,
            3
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            10.5,
            4.5,
            8.5,
            5.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        6.5,
        3,
        11.5
      ],
      "to": [
        9.5,
        5,
        12.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          1.5,
          2.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            10.5,
            4.5,
            12,
            5.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            7,
            3,
            7.5,
            4
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            11,
            1.5,
            12.5,
            2.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            8.5,
            7,
            9,
            8
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            13,
            4.5,
            11.5,
            4
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            6.5,
            11.5,
            5,
            12
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        6.5,
        3,
        3.5
      ],
      "to": [
        9.5,
        5.5,
        4.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          1.5,
          -5.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            3,
            8.5,
            4.5,
            9.75
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            12,
            0,
            12.5,
            1.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            8.5,
            5.5,
            10,
            6.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            1,
            12,
            1.5,
            13.25
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            8,
            12,
            6.5,
            11.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            13,
            7,
            11.5,
            7.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        6.5,
        3,
        4
      ],
      "to": [
        9.5,
        6,
        6.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          1.5,
          -3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            7.5,
            8,
            9,
            9.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            9,
            3,
            10.25,
            4.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            1.5,
            8.5,
            3,
            10
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            9,
            7,
            10.25,
            8.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            10.5,
            9.75,
            9,
            8.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            1.5,
            9.5,
            0,
            10.75
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        8,
        3.3,
        1
      ],
      "to": [
        8,
        7.3,
        7.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          1.8,
          -3.5
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
            0,
            0,
            3.25,
            2
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
            0,
            2,
            3.25,
            4
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0,
            3.25,
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
            3.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        6,
        3,
        4
      ],
      "to": [
        10,
        5.5,
        6.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          1.5,
          -3.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            4.5,
            5,
            6.5,
            6.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            9.5,
            0,
            10.75,
            1.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            4.5,
            6.5,
            6.5,
            7.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            9.5,
            1.5,
            10.75,
            2.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            8.5,
            6.25,
            6.5,
            5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            8.5,
            6.5,
            6.5,
            7.75
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        7.7,
        5.5,
        10.5
      ],
      "to": [
        7.7,
        6.5,
        11.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          6.2,
          1.5,
          1.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            0.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            8.5,
            9.5,
            9,
            10
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            0.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            1,
            11,
            1.5,
            11.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0,
            0.5,
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
            0.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        8.5,
        5.5,
        10.5
      ],
      "to": [
        8.5,
        6.5,
        11.5
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.5,
          1.5,
          1.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            0.5
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0.5,
            14,
            1,
            14.5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            0.5
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            1,
            14,
            1.5,
            14.5
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0,
            0.5,
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
            0.5
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        7.9,
        6,
        10.3
      ],
      "to": [
        8.4,
        6.5,
        12.8
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          6.9,
          1.5,
          1.8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            14.5,
            0,
            14.75,
            0.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            13,
            4,
            14.25,
            4.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0.5,
            14.5,
            0.75,
            14.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            4.5,
            13,
            5.75,
            13.25
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            7.75,
            13.25,
            7.5,
            12
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            0.25,
            13,
            0,
            14.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        9.5,
        3,
        6.5
      ],
      "to": [
        10,
        5,
        12
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          1.5,
          2.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            1.5,
            14,
            1.75,
            15
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            4.5,
            4,
            7.25,
            5
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            2,
            14,
            2.25,
            15
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            5,
            0,
            7.75,
            1
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            11.75,
            10.25,
            11.5,
            7.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            8.25,
            11.5,
            8,
            14.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        6,
        3,
        6.5
      ],
      "to": [
        6.5,
        5,
        12
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          3.5,
          1.5,
          2.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            2.5,
            14,
            2.75,
            15
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            5,
            1,
            7.75,
            2
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            3,
            14,
            3.25,
            15
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            5,
            2,
            7.75,
            3
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            8.75,
            14.25,
            8.5,
            11.5
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            9.25,
            11.5,
            9,
            14.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        6.5,
        5,
        6.5
      ],
      "to": [
        9.5,
        5.5,
        12
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          1,
          2.5
        ]
      },
      "faces": {
        "north": {
          "uv": [
            13,
            2.5,
            14.5,
            2.75
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            9.5,
            11.5,
            12.25,
            11.75
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            3,
            13,
            4.5,
            13.25
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            11.5,
            10.5,
            14.25,
            10.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            3,
            6.75,
            1.5,
            4
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            4.5,
            4,
            3,
            6.75
          ],
          "texture": "#0"
        }
      }
    }
  ],
  "display": {
    "thirdperson_righthand": {
      "translation": [
        0,
        7,
        2
      ]
    },
    "thirdperson_lefthand": {
      "translation": [
        0,
        7,
        2
      ]
    },
    "firstperson_righthand": {
      "rotation": [
        -4.57,
        31.2,
        8.79
      ],
      "translation": [
        0,
        8,
        0
      ]
    },
    "firstperson_lefthand": {
      "rotation": [
        -4.57,
        31.2,
        8.79
      ],
      "translation": [
        0,
        8,
        0
      ]
    },
    "ground": {
      "translation": [
        0,
        5.25,
        0
      ]
    },
    "gui": {
      "rotation": [
        -160.5,
        46,
        -180
      ],
      "translation": [
        0.75,
        5.5,
        0
      ],
      "scale": [
        1.13867,
        1.13867,
        1.13867
      ]
    }
  }
}
'@

$TexturePath = Join-Path $Root "src/main/resources/assets/droingos_decor/textures/block/earth_roamer.png"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $TexturePath) | Out-Null
[System.IO.File]::WriteAllBytes(
    $TexturePath,
    [Convert]::FromBase64String("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")
)

Write-Utf8NoBom "src/main/resources/assets/droingos_decor/blockstates/half_decor_container.json" @'
{
  "variants": {
    "": {
      "model": "minecraft:block/air"
    }
  }
}
'@

Write-Utf8NoBom "src/main/resources/assets/droingos_decor/models/item/half_decor_container.json" @'
{
  "parent": "minecraft:item/generated"
}
'@

# Merge language entries conservatively.
$LangPath = Join-Path $Root "src/main/resources/assets/droingos_decor/lang/en_us.json"
if (Test-Path -LiteralPath $LangPath) {
    Backup-File "src/main/resources/assets/droingos_decor/lang/en_us.json"
    $Lang = Get-Content -LiteralPath $LangPath -Raw | ConvertFrom-Json
    $Lang | Add-Member -NotePropertyName "item.droingos_decor.earth_roamer" -NotePropertyValue "Earth Roamer" -Force
    $Lang | Add-Member -NotePropertyName "itemGroup.droingos_decor.category.half_blocks" -NotePropertyValue "Half Blocks" -Force
    $Json = $Lang | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($LangPath, $Json, $Utf8NoBom)
}

Write-Host ""
Write-Host "Installed Earth Roamer half-block decor."
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
Write-Host "  1. Earth Roamer appears under Half Blocks."
Write-Host "  2. It places only on top faces."
Write-Host "  3. Shift-right-click rotates it."
Write-Host "  4. Right-click pushes it forward and back while wheels roll."
Write-Host "  5. Punching picks it up."
