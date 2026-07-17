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