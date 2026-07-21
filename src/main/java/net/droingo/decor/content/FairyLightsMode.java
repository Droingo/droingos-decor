package net.droingo.decor.content;

public enum FairyLightsMode {
    STEADY("Steady"),
    ALTERNATING("Alternating"),
    CHASE("Chase"),
    TWINKLE("Twinkle"),
    PULSE("Pulse"),
    OFF("Off");

    private final String displayName;

    FairyLightsMode(String displayName) {
        this.displayName = displayName;
    }

    public String displayName() {
        return displayName;
    }

    public FairyLightsMode next() {
        FairyLightsMode[] values = values();
        return values[(ordinal() + 1) % values.length];
    }

    public static FairyLightsMode byOrdinal(int ordinal) {
        FairyLightsMode[] values = values();
        if (ordinal < 0 || ordinal >= values.length) {
            return STEADY;
        }
        return values[ordinal];
    }
}