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

$SeatPath = "src/main/java/net/droingo/decor/entity/BeastSkullSeatEntity.java"
$RendererPath = "src/main/java/net/droingo/decor/client/render/BeastSkullRenderer.java"
$BlockPath = Join-Path $Root "src/main/java/net/droingo/decor/content/BeastSkullBlock.java"

if (-not (Test-Path -LiteralPath (Join-Path $Root $SeatPath))) {
    throw "Could not find BeastSkullSeatEntity.java. Run this from the Droingo's Decor project root."
}

if (-not (Test-Path -LiteralPath (Join-Path $Root $RendererPath))) {
    throw "Could not find BeastSkullRenderer.java. Run this from the Droingo's Decor project root."
}

if (-not (Test-Path -LiteralPath $BlockPath)) {
    throw "Could not find BeastSkullBlock.java. Run this from the Droingo's Decor project root."
}

Write-Utf8NoBom $SeatPath @'
package net.droingo.decor.entity;

import net.droingo.decor.content.BeastSkullBlock;
import net.droingo.decor.content.BeastSkullPlacement;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.Pose;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;

public final class BeastSkullSeatEntity extends Entity {
    private BlockPos parentPos = BlockPos.ZERO;
    private Direction facing = Direction.NORTH;

    public BeastSkullSeatEntity(EntityType<? extends BeastSkullSeatEntity> type, Level level) {
        super(type, level);
        noPhysics = true;
        setNoGravity(true);
    }

    public void setParent(BlockPos pos, Direction facing) {
        this.parentPos = pos.immutable();
        this.facing = facing;
        setYRot(facing.toYRot());
        setYHeadRot(facing.toYRot());
    }

    public BlockPos parentPos() {
        return parentPos;
    }

    @Override
    protected void defineSynchedData(SynchedEntityData.Builder builder) {
    }

    @Override
    public void tick() {
        super.tick();
        noPhysics = true;
        setNoGravity(true);

        if (!level().isClientSide) {
            var state = level().getBlockState(parentPos);
            if (!(state.getBlock() instanceof BeastSkullBlock)
                    || state.getValue(BeastSkullBlock.PLACEMENT) != BeastSkullPlacement.FLOOR
                    || !isVehicle()) {
                discard();
            }
        }
    }

    @Override
    protected boolean canAddPassenger(Entity passenger) {
        return getPassengers().isEmpty();
    }

    @Override
    protected void positionRider(Entity passenger, MoveFunction move) {
        if (!hasPassenger(passenger)) {
            return;
        }

        /*
         * Use the seat entity's synchronized world position instead of parentPos.
         * parentPos is save data and was still BlockPos.ZERO on the client, which
         * caused the client-side passenger update to place the player at 0, 0, 0.
         */
        double yaw = Math.toRadians(getYRot());
        double forward = 0.10D;
        double x = getX() - Math.sin(yaw) * forward;
        double z = getZ() + Math.cos(yaw) * forward;
        double y = getY() - 0.03D;

        move.accept(passenger, x, y, z);
        passenger.setYRot(getYRot());
        passenger.setYHeadRot(getYRot());
        passenger.setPose(Pose.SWIMMING);
    }

    @Override
    public Vec3 getDismountLocationForPassenger(net.minecraft.world.entity.LivingEntity passenger) {
        double yaw = Math.toRadians(getYRot());
        return new Vec3(
                getX() - Math.sin(yaw) * 1.25D,
                getY() - 0.46D,
                getZ() + Math.cos(yaw) * 1.25D
        );
    }

    @Override
    protected void readAdditionalSaveData(CompoundTag tag) {
        parentPos = BlockPos.of(tag.getLong("Parent"));
        facing = Direction.from2DDataValue(tag.getInt("Facing"));
        setYRot(facing.toYRot());
        setYHeadRot(facing.toYRot());
    }

    @Override
    protected void addAdditionalSaveData(CompoundTag tag) {
        tag.putLong("Parent", parentPos.asLong());
        tag.putInt("Facing", facing.get2DDataValue());
    }

    @Override
    public boolean isPickable() {
        return false;
    }

    @Override
    public boolean isPushable() {
        return false;
    }
}
'@

Write-Utf8NoBom $RendererPath @'
package net.droingo.decor.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import net.droingo.decor.DroingosDecor;
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
import net.minecraft.world.level.block.Blocks;
import net.neoforged.neoforge.client.model.data.ModelData;

public final class BeastSkullRenderer implements BlockEntityRenderer<BeastSkullBlockEntity> {
    public BeastSkullRenderer(BlockEntityRendererProvider.Context context) {
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
                be.getBlockState().getValue(BeastSkullBlock.PLACEMENT);
        Direction facing =
                be.getBlockState().getValue(BeastSkullBlock.FACING);
        String variant = placement.getSerializedName();

        pose.pushPose();
        pose.translate(0.5D, 0.0D, 0.5D);

        /*
         * Every supplied model is authored facing north. Its wall support is on
         * the south side of the model, so NORTH must be zero rotation.
         */
        pose.mulPose(Axis.YP.rotationDegrees(rotationForFacing(facing)));
        pose.translate(-0.5D, 0.0D, -0.5D);

        renderModel(
                model("the_beast_" + variant + "_static"),
                pose,
                buffers,
                light,
                overlay
        );

        JawPivot pivot = jawPivot(placement);
        pose.pushPose();
        pose.translate(pivot.x(), pivot.y(), pivot.z());
        pose.mulPose(Axis.XP.rotationDegrees(jawAngle(be, partialTick)));
        pose.translate(-pivot.x(), -pivot.y(), -pivot.z());

        renderModel(
                model("the_beast_" + variant + "_jaw"),
                pose,
                buffers,
                light,
                overlay
        );

        pose.popPose();
        pose.popPose();
    }

    private static float rotationForFacing(Direction facing) {
        return switch (facing) {
            case NORTH -> 0.0F;
            case EAST -> 90.0F;
            case SOUTH -> 180.0F;
            case WEST -> -90.0F;
            default -> 0.0F;
        };
    }

    private static JawPivot jawPivot(BeastSkullPlacement placement) {
        /*
         * These are the actual jaw-group pivots from each supplied Blockbench
         * placement model. They are intentionally different.
         */
        return switch (placement) {
            case FLOOR -> new JawPivot(
                    8.0D / 16.0D,
                    19.75D / 16.0D,
                    11.0D / 16.0D
            );
            case WALL -> new JawPivot(
                    8.0D / 16.0D,
                    10.75D / 16.0D,
                    5.0D / 16.0D
            );
            case CEILING -> new JawPivot(
                    8.0D / 16.0D,
                    2.75D / 16.0D,
                    15.0D / 16.0D
            );
        };
    }

    private static float jawAngle(BeastSkullBlockEntity be, float partialTick) {
        if (be.getLevel() == null || be.animationStart() == Long.MIN_VALUE) {
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
                    yield (1.0F - ease((t - 13.0F) / 11.0F)) * 42.0F;
                }
                yield 0.0F;
            }
            case BeastSkullBlockEntity.ANIMATION_CHEW -> {
                float phase = (t % 24.0F) / 24.0F;
                yield 12.0F
                        + (0.5F
                        - 0.5F
                        * (float) Math.cos(phase * Math.PI * 2.0D))
                        * 24.0F;
            }
            case BeastSkullBlockEntity.ANIMATION_HARD_BITE ->
                    t < 5.0F
                            ? (1.0F - ease(t / 5.0F)) * 35.0F
                            : 0.0F;
            default -> 0.0F;
        };
    }

    private static float ease(float value) {
        float x = Math.max(0.0F, Math.min(1.0F, value));
        return x * x * (3.0F - 2.0F * x);
    }

    private static ResourceLocation model(String name) {
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
        Minecraft minecraft = Minecraft.getInstance();
        BakedModel baked = minecraft.getModelManager().getModel(
                ModelResourceLocation.standalone(location)
        );
        BlockRenderDispatcher dispatcher = minecraft.getBlockRenderer();

        dispatcher.getModelRenderer().renderModel(
                pose.last(),
                buffers.getBuffer(RenderType.cutout()),
                Blocks.AIR.defaultBlockState(),
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
    public boolean shouldRenderOffScreen(BeastSkullBlockEntity blockEntity) {
        return true;
    }

    private record JawPivot(double x, double y, double z) {
    }
}
'@

$BlockText = [System.IO.File]::ReadAllText($BlockPath)

# Remove the old sneak-right-click rotation branch entirely.
$RotationPattern = '(?s)\s*if \(player\.isShiftKeyDown\(\)\) \{\s*if \(!level\.isClientSide\) \{\s*level\.setBlock\(pos, state\.setValue\(FACING, state\.getValue\(FACING\)\.getClockWise\(\)\), 3\);\s*\}\s*return InteractionResult\.sidedSuccess\(level\.isClientSide\);\s*\}\s*'
$BlockText = [regex]::Replace($BlockText, $RotationPattern, "`r`n")

# Keep the NeoForge-required public ticker visibility even when this script is
# run after the original installer rather than after the compile repair.
$BlockText = $BlockText.Replace(
    "protected <T extends BlockEntity> BlockEntityTicker<T> getTicker(",
    "public <T extends BlockEntity> BlockEntityTicker<T> getTicker("
)

[System.IO.File]::WriteAllText($BlockPath, $BlockText, $Utf8NoBom)

Write-Host ""
Write-Host "Fixed Beast Skull seat positioning, wall orientation, jaw pivots, and removed rotation."
Write-Host "Building..."
Write-Host ""

& ".\gradlew.bat" build

if ($LASTEXITCODE -ne 0) {
    throw "Build failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Build successful."
