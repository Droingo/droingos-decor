package net.droingo.decor.content;

import net.minecraft.core.BlockPos;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.state.BlockState;

public final class DecorPlacementSounds {
    private DecorPlacementSounds() {
    }

    public static void play(
            Level level,
            BlockPos pos,
            Player player
    ) {
        if (level.isClientSide) {
            return;
        }

        BlockState state = level.getBlockState(pos);

        SoundType soundType = state.getSoundType(
                level,
                pos,
                player
        );

        level.playSound(
                null,
                pos,
                soundType.getPlaceSound(),
                SoundSource.BLOCKS,
                (soundType.getVolume() + 1.0F) / 2.0F,
                soundType.getPitch() * 0.8F
        );
    }
}