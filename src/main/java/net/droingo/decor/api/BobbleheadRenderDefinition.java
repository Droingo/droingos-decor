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