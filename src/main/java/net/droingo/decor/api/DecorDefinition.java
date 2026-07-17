package net.droingo.decor.api;

import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import org.jetbrains.annotations.Nullable;

import java.util.Objects;
import java.util.function.Supplier;

public final class DecorDefinition {
    private final ResourceLocation id;
    private final DecorCategory category;
    private final DecorPlacementType placementType;
    private final Supplier<? extends Item> itemSupplier;
    private final DecorInteraction interaction;
    private final double minX;
    private final double minY;
    private final double minZ;
    private final double maxX;
    private final double maxY;
    private final double maxZ;
    private final @Nullable BobbleheadRenderDefinition bobbleheadRender;

    private DecorDefinition(Builder builder) {
        this.id = builder.id;
        this.category = builder.category;
        this.placementType = builder.placementType;
        this.itemSupplier = builder.itemSupplier;
        this.interaction = builder.interaction;
        this.minX = builder.minX;
        this.minY = builder.minY;
        this.minZ = builder.minZ;
        this.maxX = builder.maxX;
        this.maxY = builder.maxY;
        this.maxZ = builder.maxZ;
        this.bobbleheadRender = builder.bobbleheadRender;
    }

    public static Builder builder(ResourceLocation id) {
        return new Builder(id);
    }

    public ResourceLocation id() { return id; }
    public DecorCategory category() { return category; }
    public DecorPlacementType placementType() { return placementType; }
    public DecorInteraction interaction() { return interaction; }
    public double minX() { return minX; }
    public double minY() { return minY; }
    public double minZ() { return minZ; }
    public double maxX() { return maxX; }
    public double maxY() { return maxY; }
    public double maxZ() { return maxZ; }
    public @Nullable BobbleheadRenderDefinition bobbleheadRender() { return bobbleheadRender; }

    public ItemStack pickupStack() {
        return new ItemStack(itemSupplier.get());
    }

    public static final class Builder {
        private final ResourceLocation id;
        private DecorCategory category = DecorCategory.SMALL_DECOR;
        private DecorPlacementType placementType = DecorPlacementType.TINY;
        private Supplier<? extends Item> itemSupplier;
        private DecorInteraction interaction = DecorInteraction.NONE;
        private double minX = -0.125D;
        private double minY = 0.0D;
        private double minZ = -0.125D;
        private double maxX = 0.125D;
        private double maxY = 0.5D;
        private double maxZ = 0.125D;
        private BobbleheadRenderDefinition bobbleheadRender;

        private Builder(ResourceLocation id) {
            this.id = Objects.requireNonNull(id);
        }

        public Builder category(DecorCategory category) {
            this.category = Objects.requireNonNull(category);
            return this;
        }

        public Builder placement(DecorPlacementType placementType) {
            this.placementType = Objects.requireNonNull(placementType);
            return this;
        }

        public Builder item(Supplier<? extends Item> itemSupplier) {
            this.itemSupplier = Objects.requireNonNull(itemSupplier);
            return this;
        }

        public Builder interaction(DecorInteraction interaction) {
            this.interaction = Objects.requireNonNull(interaction);
            return this;
        }

        public Builder bounds(
                double minX, double minY, double minZ,
                double maxX, double maxY, double maxZ
        ) {
            this.minX = minX;
            this.minY = minY;
            this.minZ = minZ;
            this.maxX = maxX;
            this.maxY = maxY;
            this.maxZ = maxZ;
            return this;
        }

        public Builder bobblehead(BobbleheadRenderDefinition renderDefinition) {
            this.bobbleheadRender = Objects.requireNonNull(renderDefinition);
            return this;
        }

        public DecorDefinition build() {
            if (itemSupplier == null) {
                throw new IllegalStateException("Decor definition " + id + " has no item supplier");
            }
            return new DecorDefinition(this);
        }
    }
}