package net.droingo.decor.api;

import net.droingo.decor.content.DecorContainerBlockEntity;
import net.minecraft.core.BlockPos;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;

@FunctionalInterface
public interface DecorInteraction {
    DecorInteraction NONE = (level, pos, player, container, slot) ->
            InteractionResult.sidedSuccess(level.isClientSide);

    InteractionResult interact(
            Level level,
            BlockPos pos,
            Player player,
            DecorContainerBlockEntity container,
            int slot
    );
}