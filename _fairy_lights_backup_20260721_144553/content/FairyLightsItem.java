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