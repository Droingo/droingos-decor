package net.droingo.decor.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import net.droingo.decor.entity.BeastSkullSeatEntity;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.entity.EntityRenderer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.resources.ResourceLocation;

public final class BeastSkullSeatRenderer extends EntityRenderer<BeastSkullSeatEntity> {
    private static final ResourceLocation TEXTURE = ResourceLocation.withDefaultNamespace("textures/misc/white.png");
    public BeastSkullSeatRenderer(EntityRendererProvider.Context context) { super(context); }
    @Override public void render(BeastSkullSeatEntity entity, float yaw, float partialTick, PoseStack pose, MultiBufferSource buffer, int light) { }
    @Override public ResourceLocation getTextureLocation(BeastSkullSeatEntity entity) { return TEXTURE; }
}
