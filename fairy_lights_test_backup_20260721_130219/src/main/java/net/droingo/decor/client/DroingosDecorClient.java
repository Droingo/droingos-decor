package net.droingo.decor.client;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.api.BobbleheadRenderDefinition;
import net.droingo.decor.api.DecorDefinition;
import net.droingo.decor.api.GravityWallRenderDefinition;
import net.droingo.decor.client.render.CeilingPlantRenderer;
import net.droingo.decor.client.render.BeastSkullRenderer;
import net.droingo.decor.client.render.BeastSkullSeatRenderer;
import net.droingo.decor.client.render.DecorContainerRenderer;
import net.droingo.decor.client.render.HalfDecorRenderer;
import net.droingo.decor.client.render.WallDecorRenderer;
import net.droingo.decor.registry.DecorBlockEntities;
import net.droingo.decor.registry.DecorEntities;
import net.droingo.decor.registry.DecorDefinitionRegistry;
import net.minecraft.client.resources.model.ModelResourceLocation;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.client.event.EntityRenderersEvent;
import net.neoforged.neoforge.client.event.ModelEvent;

@EventBusSubscriber(
        modid = DroingosDecor.MOD_ID,
        value = Dist.CLIENT,
        bus = EventBusSubscriber.Bus.MOD
)
public final class DroingosDecorClient {
    private DroingosDecorClient() {
    }

    @SubscribeEvent
    public static void registerBlockEntityRenderers(
            EntityRenderersEvent.RegisterRenderers event
    ) {
        event.registerBlockEntityRenderer(
                DecorBlockEntities.BEAST_SKULL.get(),
                BeastSkullRenderer::new
        );
        event.registerEntityRenderer(
                DecorEntities.BEAST_SKULL_SEAT.get(),
                BeastSkullSeatRenderer::new
        );
event.registerBlockEntityRenderer(
                DecorBlockEntities.CEILING_PLANT.get(),
                CeilingPlantRenderer::new
        );
        event.registerBlockEntityRenderer(
                DecorBlockEntities.DECOR_CONTAINER.get(),
                DecorContainerRenderer::new
        );

        event.registerBlockEntityRenderer(
                DecorBlockEntities.HALF_DECOR_CONTAINER.get(),
                HalfDecorRenderer::new
        );

        event.registerBlockEntityRenderer(
                DecorBlockEntities.WALL_DECOR_CONTAINER.get(),
                WallDecorRenderer::new
        );
    }

    @SubscribeEvent
    public static void registerAdditionalModels(
            ModelEvent.RegisterAdditional event
    ) {
        for (String modelName : java.util.List.of(
                "the_beast_floor_static",
                "the_beast_floor_jaw",
                "the_beast_wall_static",
                "the_beast_wall_jaw",
                "the_beast_ceiling_static",
                "the_beast_ceiling_jaw"
        )) {
            event.register(
                    ModelResourceLocation.standalone(
                            net.minecraft.resources.ResourceLocation.fromNamespaceAndPath(
                                    DroingosDecor.MOD_ID,
                                    "block/" + modelName
                            )
                    )
            );
        }
        event.register(
                ModelResourceLocation.standalone(
                        net.minecraft.resources.ResourceLocation
                                .fromNamespaceAndPath(
                                        DroingosDecor.MOD_ID,
                                        "block/potted_plant_ceiling_pot_vine0"
                                )
                )
        );

        event.register(
                ModelResourceLocation.standalone(
                        net.minecraft.resources.ResourceLocation
                                .fromNamespaceAndPath(
                                        DroingosDecor.MOD_ID,
                                        "block/potted_plant_ceiling_vine1"
                                )
                )
        );

        event.register(
                ModelResourceLocation.standalone(
                        net.minecraft.resources.ResourceLocation
                                .fromNamespaceAndPath(
                                        DroingosDecor.MOD_ID,
                                        "block/potted_plant_ceiling_vine2"
                                )
                )
        );

        event.register(
                ModelResourceLocation.standalone(
                        net.minecraft.resources.ResourceLocation
                                .fromNamespaceAndPath(
                                        DroingosDecor.MOD_ID,
                                        "block/potted_plant_ceiling_vine3"
                                )
                )
        );

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

        for (DecorDefinition definition : DecorDefinitionRegistry.all()) {
            BobbleheadRenderDefinition bobblehead =
                    definition.bobbleheadRender();

            if (bobblehead != null) {
                event.register(
                        ModelResourceLocation.standalone(
                                bobblehead.bodyModel()
                        )
                );

                event.register(
                        ModelResourceLocation.standalone(
                                bobblehead.movingModel()
                        )
                );
            }

            GravityWallRenderDefinition gravityWall =
                    definition.gravityWallRender();

            if (gravityWall != null) {
                event.register(
                        ModelResourceLocation.standalone(
                                gravityWall.fixedModel()
                        )
                );

                event.register(
                        ModelResourceLocation.standalone(
                                gravityWall.movingModel()
                        )
                );
            }
        }
    }
}