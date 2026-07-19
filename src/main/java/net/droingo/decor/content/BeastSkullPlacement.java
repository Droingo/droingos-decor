package net.droingo.decor.content;

import net.minecraft.util.StringRepresentable;

public enum BeastSkullPlacement implements StringRepresentable {
    FLOOR("floor"), WALL("wall"), CEILING("ceiling");

    private final String name;
    BeastSkullPlacement(String name) { this.name = name; }
    @Override public String getSerializedName() { return name; }
}
