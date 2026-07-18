package net.droingo.decor.api;

import net.minecraft.network.chat.Component;

public enum DecorCategory {
    BOBBLEHEADS("bobbleheads", 0),
    HALF_BLOCKS("half_blocks", 5),
    WALL_DECOR("wall_decor", 10),
    HANGING_DECOR("hanging_decor", 20),
    SMALL_DECOR("small_decor", 30),
    FURNITURE("furniture", 40),
    LIGHTING("lighting", 50),
    OUTDOOR_DECOR("outdoor_decor", 60),
    OVERLAYS("overlays", 70);

    private final String translationKeyPart;
    private final int order;

    DecorCategory(
            String translationKeyPart,
            int order
    ) {
        this.translationKeyPart =
                translationKeyPart;

        this.order = order;
    }

    public Component title() {
        return Component.translatable(
                "itemGroup.droingos_decor.category."
                        + translationKeyPart
        );
    }

    public int order() {
        return order;
    }
}
