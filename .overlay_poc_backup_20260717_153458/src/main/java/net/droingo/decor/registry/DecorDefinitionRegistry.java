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
                            if (!level.isClientSide) {
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