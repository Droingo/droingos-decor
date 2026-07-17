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