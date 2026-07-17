package net.droingo.decor.content.overlay;

import net.droingo.decor.DroingosDecor;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.entity.Display;
import net.minecraft.world.phys.AABB;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.event.level.BlockEvent;

import java.util.List;

/**
 * Removes overlay displays when their supporting block is deliberately broken.
 *
 * Explosion and piston handling can be added after this proof of concept is
 * approved.
 */
@EventBusSubscriber(modid = DroingosDecor.MOD_ID)
public final class OverlayEvents {
    private OverlayEvents() {
    }

    @SubscribeEvent
    public static void onBlockBroken(BlockEvent.BreakEvent event) {
        if (!(event.getLevel() instanceof ServerLevel level)) {
            return;
        }

        AABB searchBox =
                new AABB(event.getPos()).inflate(1.1D);

        List<Display.ItemDisplay> overlays =
                level.getEntitiesOfClass(
                        Display.ItemDisplay.class,
                        searchBox,
                        display ->
                                OverlayItem.isOverlay(display)
                                        && OverlayItem
                                        .getSupportPos(display)
                                        .equals(event.getPos())
                );

        for (Display.ItemDisplay overlay : overlays) {
            overlay.discard();
        }
    }
}