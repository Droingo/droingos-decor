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

import java.util.UUID;

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

        BlockPos clickedAnchor = placementBlockPos(
                context.getClickedPos(),
                context.getClickedFace()
        );

        if (!data.getBoolean(HAS_FIRST)) {
            data.putBoolean(HAS_FIRST, true);
            data.putString(
                    DIMENSION,
                    level.dimension().location().toString()
            );
            data.putLong(ANCHOR_POS, clickedAnchor.asLong());
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
            return InteractionResult.FAIL;
        }

        Vec3 firstPoint = firstPoint(data);
        BlockPos firstAnchor = BlockPos.of(data.getLong(ANCHOR_POS));
        Vec3 secondPoint = clickedPoint;
        BlockPos secondAnchor = clickedAnchor;

        double distance = firstPoint.distanceTo(secondPoint);

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

        if (!canUseAnchor(level, firstAnchor)
                || !canUseAnchor(level, secondAnchor)) {
            clear(player);

            if (!level.isClientSide) {
                player.displayClientMessage(
                        Component.literal(
                                "One of the fairy-light mounting points is obstructed."
                        ),
                        true
                );
            }

            return InteractionResult.FAIL;
        }

        if (!level.isClientSide) {
            placeAnchorIfNeeded(level, firstAnchor);
            placeAnchorIfNeeded(level, secondAnchor);

            FairyLightsTestBlockEntity.Connection connection =
                    new FairyLightsTestBlockEntity.Connection(
                            UUID.randomUUID(),
                            firstAnchor,
                            secondAnchor,
                            firstPoint,
                            secondPoint,
                            FairyLightsMode.STEADY,
                            context.isSecondaryUseActive()
                                    ? 0.08D
                                    : 0.22D,
                            colorFromStack(context.getItemInHand())
                    );

            if (level.getBlockEntity(firstAnchor)
                    instanceof FairyLightsTestBlockEntity firstLights) {
                firstLights.addConnectionRecord(connection);
            }

            if (!firstAnchor.equals(secondAnchor)
                    && level.getBlockEntity(secondAnchor)
                    instanceof FairyLightsTestBlockEntity secondLights) {
                secondLights.addConnectionRecord(connection);
            }

            if (!player.getAbilities().instabuild) {
                context.getItemInHand().shrink(1);
            }

            player.displayClientMessage(
                    Component.literal(
                            "Fairy lights placed with two interactive anchors."
                    ),
                    true
            );
        }

        clear(player);
        return InteractionResult.sidedSuccess(level.isClientSide);
    }

    private static boolean canUseAnchor(Level level, BlockPos pos) {
        return level.getBlockState(pos).is(DecorBlocks.FAIRY_LIGHTS_TEST)
                || level.getBlockState(pos).canBeReplaced();
    }

    private static void placeAnchorIfNeeded(Level level, BlockPos pos) {
        if (!level.getBlockState(pos).is(DecorBlocks.FAIRY_LIGHTS_TEST)) {
            level.setBlock(
                    pos,
                    DecorBlocks.FAIRY_LIGHTS_TEST
                            .get()
                            .defaultBlockState(),
                    3
            );
        }
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