package net.droingo.decor.registry;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.api.BobbleheadRenderDefinition;
import net.droingo.decor.api.DecorCategory;
import net.droingo.decor.api.DecorDefinition;
import net.droingo.decor.api.DecorPlacementType;
import net.droingo.decor.api.GravityWallRenderDefinition;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import org.joml.Vector3d;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class DecorDefinitionRegistry {
    private static final Map<ResourceLocation, DecorDefinition> DEFINITIONS =
            new LinkedHashMap<>();

    private static final List<String> SWEATER_QUIPS = List.of(
            "It smells bad.",
            "Has this ever been washed?",
            "It is still damp.",
            "Whose sweater is this?",
            "There is something in the pocket.",
            "It has seen better days.",
            "You probably should not wear this.",
            "It smells vaguely familiar.",
            "That stain is permanent.",
            "Maybe leave it where it is."
    );

    private static boolean bootstrapped;

    private DecorDefinitionRegistry() {
    }

    public static void bootstrap() {
        if (bootstrapped) {
            return;
        }

        bootstrapped = true;

        ResourceLocation parrotId = id("bobble_parrot");

        register(
                DecorDefinition.builder(parrotId)
                        .category(DecorCategory.BOBBLEHEADS)
                        .placement(DecorPlacementType.TINY)
                        .item(DecorItems.BOBBLE_PARROT::get)
                        .bounds(
                                -0.118D,
                                0.0D,
                                -0.238D,
                                0.118D,
                                0.755D,
                                0.141D
                        )
                        .bobblehead(
                                new BobbleheadRenderDefinition(
                                        model("bobble_parrot_body"),
                                        model("bobble_parrot_head"),
                                        new Vector3d(
                                                8.0D / 16.0D,
                                                3.2D / 16.0D,
                                                7.3D / 16.0D
                                        ),
                                        1.5F
                                )
                        )
                        .interaction((level, pos, player, container, slot) -> {
                            if (level.isClientSide) {
                                net.droingo.decor.client.animation
                                        .BobbleheadInteractionPulses
                                        .trigger(container, slot);
                            } else {
                                float pitch =
                                        1.45F
                                                + level.random.nextFloat()
                                                * 0.25F;

                                level.playSound(
                                        null,
                                        pos,
                                        SoundEvents.PARROT_AMBIENT,
                                        SoundSource.BLOCKS,
                                        0.85F,
                                        pitch
                                );
                            }

                            return net.minecraft.world.InteractionResult
                                    .sidedSuccess(level.isClientSide);
                        })
                        .build()
        );

        ResourceLocation earthRoamerId = id("earth_roamer");

        register(
                DecorDefinition.builder(earthRoamerId)
                        .category(DecorCategory.HALF_BLOCKS)
                        .placement(DecorPlacementType.HALF_BLOCK)
                        .item(DecorItems.EARTH_ROAMER::get)
                        .bounds(
                                -0.375D,
                                0.0D,
                                -0.4375D,
                                0.375D,
                                0.4375D,
                                0.4375D
                        )
                        .build()
        );
        ResourceLocation pumpkinId = id("pumpkin_bobble");

        register(
                DecorDefinition.builder(pumpkinId)
                        .category(DecorCategory.BOBBLEHEADS)
                        .placement(DecorPlacementType.TINY)
                        .item(DecorItems.PUMPKIN_BOBBLE::get)
                        .bounds(
                                -0.135D,
                                0.0D,
                                -0.225D,
                                0.135D,
                                0.50D,
                                0.225D
                        )
                        .bobblehead(
                                new BobbleheadRenderDefinition(
                                        model("pumpkin_bobble_body"),
                                        model("pumpkin_bobble_head"),
                                        new Vector3d(
                                                8.0D / 16.0D,
                                                3.2D / 16.0D,
                                                7.5D / 16.0D
                                        ),
                                        1.5F
                                )
                        )
                        .interaction((level, pos, player, container, slot) -> {
                            if (level.isClientSide) {
                                net.droingo.decor.client.animation
                                        .BobbleheadInteractionPulses
                                        .trigger(container, slot);
                            } else {
                                /*
                                 * Mob-style pitch variation: centred on 1.0
                                 * with a small random range each interaction.
                                 */
                                float pitch =
                                        0.90F
                                                + level.random.nextFloat()
                                                * 0.20F;

                                level.playSound(
                                        null,
                                        pos,
                                        DecorSounds.PUMPKIN_CAW.get(),
                                        SoundSource.BLOCKS,
                                        0.90F,
                                        pitch
                                );
                            }

                            return net.minecraft.world.InteractionResult
                                    .sidedSuccess(level.isClientSide);
                        })
                        .build()
        );
        ResourceLocation buddyId = id("buddy_bobblehead");

        register(
                DecorDefinition.builder(buddyId)
                        .category(DecorCategory.BOBBLEHEADS)
                        .placement(DecorPlacementType.TINY)
                        .item(DecorItems.BUDDY_BOBBLEHEAD::get)
                        .bounds(
                                -0.145D,
                                0.0D,
                                -0.20D,
                                0.145D,
                                0.52D,
                                0.20D
                        )
                        .bobblehead(
                                new BobbleheadRenderDefinition(
                                        model("buddy_bobble_body"),
                                        model("buddy_bobble_head"),
                                        new Vector3d(
                                                7.7D / 16.0D,
                                                2.4D / 16.0D,
                                                7.4D / 16.0D
                                        ),
                                        1.5F
                                )
                        )
                        .interaction((level, pos, player, container, slot) -> {
                            if (level.isClientSide) {
                                net.droingo.decor.client.animation
                                        .BobbleheadInteractionPulses
                                        .trigger(container, slot);
                            } else {
                                /*
                                 * Use the normal wolf ambient sound, pitched
                                 * upward to read as a young puppy.
                                 */
                                float pitch =
                                        1.45F
                                                + level.random.nextFloat()
                                                * 0.30F;

                                level.playSound(
                                        null,
                                        pos,
                                        net.minecraft.sounds.SoundEvents.WOLF_AMBIENT,
                                        SoundSource.BLOCKS,
                                        0.85F,
                                        pitch
                                );
                            }

                            return net.minecraft.world.InteractionResult
                                    .sidedSuccess(level.isClientSide);
                        })
                        .build()
        );
        ResourceLocation sweaterId = id("hanging_sweater");

        register(
                DecorDefinition.builder(sweaterId)
                        .category(DecorCategory.WALL_DECOR)
                        .placement(DecorPlacementType.WALL)
                        .item(DecorItems.HANGING_SWEATER::get)
                        .gravityWall(
                                new GravityWallRenderDefinition(
                                        model("hanging_sweater_nail"),
                                        model("hanging_sweater_cloth"),
                                        new Vector3d(
                                                8.0D / 16.0D,
                                                14.6D / 16.0D,
                                                15.0D / 16.0D
                                        ),
                                        1.0F
                                )
                        )
                        .interaction((level, pos, player, container, slot) -> {
                            if (!level.isClientSide) {
                                String quip = SWEATER_QUIPS.get(
                                        level.random.nextInt(
                                                SWEATER_QUIPS.size()
                                        )
                                );

                                player.displayClientMessage(
                                        Component.literal(quip),
                                        true
                                );
                            }

                            return net.minecraft.world.InteractionResult
                                    .sidedSuccess(level.isClientSide);
                        })
                        .build()
        );
        ResourceLocation mossyBottomId = id("mossy_bottom");

        register(
                DecorDefinition.builder(mossyBottomId)
                        .category(DecorCategory.OVERLAYS)
                        .placement(DecorPlacementType.OVERLAY)
                        .item(DecorItems.MOSSY_BOTTOM::get)
                        .build()
        );

        ResourceLocation wetBottomId = id("wet_bottom");

        register(
                DecorDefinition.builder(wetBottomId)
                        .category(DecorCategory.OVERLAYS)
                        .placement(DecorPlacementType.OVERLAY)
                        .item(DecorItems.WET_BOTTOM::get)
                        .build()
        );
    }
public static DecorDefinition register(DecorDefinition definition) {
        DecorDefinition previous =
                DEFINITIONS.putIfAbsent(definition.id(), definition);

        if (previous != null) {
            throw new IllegalStateException(
                    "Duplicate decor definition: " + definition.id()
            );
        }

        return definition;
    }

    public static DecorDefinition get(ResourceLocation id) {
        return DEFINITIONS.get(id);
    }

    public static Collection<DecorDefinition> all() {
        return List.copyOf(DEFINITIONS.values());
    }

    public static List<DecorDefinition> creativeOrder() {
        List<DecorDefinition> ordered =
                new ArrayList<>(DEFINITIONS.values());

        ordered.sort(
                Comparator
                        .comparingInt(
                                (DecorDefinition definition) ->
                                        definition.category().order()
                        )
                        .thenComparing(
                                definition ->
                                        definition.id().toString()
                        )
        );

        return ordered;
    }

    private static ResourceLocation id(String path) {
        return ResourceLocation.fromNamespaceAndPath(
                DroingosDecor.MOD_ID,
                path
        );
    }

    private static ResourceLocation model(String path) {
        return ResourceLocation.fromNamespaceAndPath(
                DroingosDecor.MOD_ID,
                "block/" + path
        );
    }
}