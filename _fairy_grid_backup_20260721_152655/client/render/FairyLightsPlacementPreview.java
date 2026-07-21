package net.droingo.decor.client.render;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.content.FairyLightsItem;
import net.droingo.decor.registry.DecorItems;
import net.minecraft.client.Minecraft;
import net.minecraft.core.particles.DustParticleOptions;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.Vec3;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.client.event.ClientTickEvent;
import org.joml.Vector3f;

@EventBusSubscriber(
        modid = DroingosDecor.MOD_ID,
        value = Dist.CLIENT
)
public final class FairyLightsPlacementPreview {
    private static final DustParticleOptions PREVIEW_PARTICLE =
            new DustParticleOptions(
                    new Vector3f(1.0F, 0.85F, 0.35F),
                    0.45F
            );

    private FairyLightsPlacementPreview() {
    }

    @SubscribeEvent
    public static void clientTick(ClientTickEvent.Post event) {
        Minecraft minecraft = Minecraft.getInstance();

        if (minecraft.level == null
                || minecraft.player == null
                || minecraft.isPaused()
                || !minecraft.player.getMainHandItem()
                        .is(DecorItems.FAIRY_LIGHTS.get())
                || !FairyLightsItem.hasFirstPoint(minecraft.player)
                || !(minecraft.hitResult instanceof BlockHitResult hit)) {
            return;
        }

        Vec3 start = FairyLightsItem.selectedPoint(minecraft.player);
        Vec3 end = FairyLightsItem.offsetFromSurface(
                hit.getLocation(),
                hit.getDirection()
        );

        double distance = start.distanceTo(end);
        if (distance < 0.05D || distance > 16.0D) {
            return;
        }

        int particles = Math.max(8, (int) Math.ceil(distance * 8.0D));
        for (int index = 0; index <= particles; index++) {
            double t = index / (double) particles;
            Vec3 point = FairyLightsTestRenderer.curve(
                    start,
                    end,
                    t,
                    minecraft.player.isShiftKeyDown() ? 0.08D : 0.22D
            );

            minecraft.level.addParticle(
                    PREVIEW_PARTICLE,
                    point.x,
                    point.y,
                    point.z,
                    0.0D,
                    0.0D,
                    0.0D
            );
        }
    }
}