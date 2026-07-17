package net.droingo.decor.client;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.client.render.DecorContainerRenderer;
import net.droingo.decor.registry.DecorBlockEntities;
import net.minecraft.client.resources.model.ModelResourceLocation;
import net.minecraft.resources.ResourceLocation;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.client.event.EntityRenderersEvent;
import net.neoforged.neoforge.client.event.ModelEvent;

@EventBusSubscriber(modid = DroingosDecor.MOD_ID, value = Dist.CLIENT, bus = EventBusSubscriber.Bus.MOD)
public final class DroingosDecorClient {
    private DroingosDecorClient() {}
    @SubscribeEvent public static void registerBlockEntityRenderers(EntityRenderersEvent.RegisterRenderers event) {
        event.registerBlockEntityRenderer(DecorBlockEntities.DECOR_CONTAINER.get(), DecorContainerRenderer::new);
    }
    @SubscribeEvent public static void registerAdditionalModels(ModelEvent.RegisterAdditional event) {
        event.register(ModelResourceLocation.standalone(ResourceLocation.fromNamespaceAndPath(DroingosDecor.MOD_ID, "block/bobble_parrot_body")));
        event.register(ModelResourceLocation.standalone(ResourceLocation.fromNamespaceAndPath(DroingosDecor.MOD_ID, "block/bobble_parrot_head")));
    }
}
