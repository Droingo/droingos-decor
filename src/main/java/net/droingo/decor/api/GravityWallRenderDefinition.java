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