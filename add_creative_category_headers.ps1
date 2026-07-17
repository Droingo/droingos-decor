$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$ProjectRoot = (Get-Location).Path
$BackupRoot = Join-Path $ProjectRoot (".decor_header_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $Target = Join-Path $ProjectRoot $RelativePath

    if (Test-Path -LiteralPath $Target) {
        $Backup = Join-Path $BackupRoot $RelativePath
        $BackupDirectory = Split-Path -Parent $Backup

        New-Item -ItemType Directory -Force -Path $BackupDirectory | Out-Null
        Copy-Item -LiteralPath $Target -Destination $Backup -Force
    }

    $Directory = Split-Path -Parent $Target
    New-Item -ItemType Directory -Force -Path $Directory | Out-Null

    [System.IO.File]::WriteAllText($Target, $Content, $Utf8NoBom)
}

function Write-Base64File {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Base64
    )

    $Target = Join-Path $ProjectRoot $RelativePath

    if (Test-Path -LiteralPath $Target) {
        $Backup = Join-Path $BackupRoot $RelativePath
        $BackupDirectory = Split-Path -Parent $Backup

        New-Item -ItemType Directory -Force -Path $BackupDirectory | Out-Null
        Copy-Item -LiteralPath $Target -Destination $Backup -Force
    }

    $Directory = Split-Path -Parent $Target
    New-Item -ItemType Directory -Force -Path $Directory | Out-Null

    [System.IO.File]::WriteAllBytes(
        $Target,
        [Convert]::FromBase64String($Base64)
    )
}

if (!(Test-Path -LiteralPath (Join-Path $ProjectRoot "build.gradle"))) {
    throw "Run this script from the Droingo's Decor project root."
}

Write-Utf8NoBom `
    "src/main/java/net/droingo/decor/registry/DecorItems.java" `
@'

package net.droingo.decor.registry;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.api.DecorCategory;
import net.droingo.decor.content.TinyDecorItem;
import net.minecraft.world.item.Item;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforge.registries.DeferredItem;
import net.neoforged.neoforge.registries.DeferredRegister;

import java.util.ArrayList;
import java.util.List;

public final class DecorItems {
    public static final DeferredRegister.Items ITEMS =
            DeferredRegister.createItems(DroingosDecor.MOD_ID);

    public static final DeferredItem<Item> BOBBLE_PARROT = ITEMS.register(
            "bobble_parrot",
            () -> new TinyDecorItem("bobble_parrot", new Item.Properties())
    );

    /*
     * Internal creative-menu layout items.
     *
     * Each category banner occupies one complete nine-slot row. These items
     * are only inserted into Droingo's Decor's own creative tab.
     */
    public static final DeferredItem<Item> CREATIVE_SPACER =
            registerInternalItem("creative_spacer");

    public static final List<DeferredItem<Item>> BOBBLEHEAD_HEADER =
            registerHeader("bobbleheads");

    public static final List<DeferredItem<Item>> WALL_DECOR_HEADER =
            registerHeader("wall_decor");

    public static final List<DeferredItem<Item>> HANGING_DECOR_HEADER =
            registerHeader("hanging_decor");

    public static final List<DeferredItem<Item>> SMALL_DECOR_HEADER =
            registerHeader("small_decor");

    public static final List<DeferredItem<Item>> FURNITURE_HEADER =
            registerHeader("furniture");

    public static final List<DeferredItem<Item>> LIGHTING_HEADER =
            registerHeader("lighting");

    public static final List<DeferredItem<Item>> OUTDOOR_DECOR_HEADER =
            registerHeader("outdoor_decor");

    private DecorItems() {
    }

    private static DeferredItem<Item> registerInternalItem(String name) {
        return ITEMS.register(
                name,
                () -> new Item(new Item.Properties().stacksTo(1))
        );
    }

    private static List<DeferredItem<Item>> registerHeader(String categoryName) {
        List<DeferredItem<Item>> pieces = new ArrayList<>(9);

        for (int index = 0; index < 9; index++) {
            pieces.add(registerInternalItem(
                    "creative_header_" + categoryName + "_" + index
            ));
        }

        return List.copyOf(pieces);
    }

    public static List<DeferredItem<Item>> creativeHeader(
            DecorCategory category
    ) {
        return switch (category) {
            case BOBBLEHEADS -> BOBBLEHEAD_HEADER;
            case WALL_DECOR -> WALL_DECOR_HEADER;
            case HANGING_DECOR -> HANGING_DECOR_HEADER;
            case SMALL_DECOR -> SMALL_DECOR_HEADER;
            case FURNITURE -> FURNITURE_HEADER;
            case LIGHTING -> LIGHTING_HEADER;
            case OUTDOOR_DECOR -> OUTDOOR_DECOR_HEADER;
        };
    }

    public static void register(IEventBus bus) {
        ITEMS.register(bus);
    }
}

 '@

Write-Utf8NoBom `
    "src/main/java/net/droingo/decor/registry/DecorCreativeTabs.java" `
@'

package net.droingo.decor.registry;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.api.DecorCategory;
import net.droingo.decor.api.DecorDefinition;
import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.CreativeModeTab;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforge.registries.DeferredHolder;
import net.neoforged.neoforge.registries.DeferredItem;
import net.neoforged.neoforge.registries.DeferredRegister;

import java.util.List;

public final class DecorCreativeTabs {
    private static final int CREATIVE_ROW_WIDTH = 9;

    public static final DeferredRegister<CreativeModeTab> TABS =
            DeferredRegister.create(
                    Registries.CREATIVE_MODE_TAB,
                    DroingosDecor.MOD_ID
            );

    public static final DeferredHolder<CreativeModeTab, CreativeModeTab> MAIN =
            TABS.register(
                    "main",
                    () -> CreativeModeTab.builder()
                            .title(Component.translatable(
                                    "itemGroup.droingos_decor.main"
                            ))
                            .icon(() -> DecorItems.BOBBLE_PARROT
                                    .get()
                                    .getDefaultInstance())
                            .displayItems((parameters, output) -> {
                                List<DecorDefinition> definitions =
                                        DecorDefinitionRegistry.creativeOrder();

                                DecorCategory activeCategory = null;
                                int occupiedSlots = 0;

                                for (DecorDefinition definition : definitions) {
                                    if (definition.category() != activeCategory) {
                                        occupiedSlots = padToNextRow(
                                                output,
                                                occupiedSlots
                                        );

                                        occupiedSlots += addHeader(
                                                output,
                                                definition.category()
                                        );

                                        activeCategory = definition.category();
                                    }

                                    output.accept(definition.pickupStack());
                                    occupiedSlots++;
                                }
                            })
                            .build()
            );

    private DecorCreativeTabs() {
    }

    private static int padToNextRow(
            CreativeModeTab.Output output,
            int occupiedSlots
    ) {
        int remainder = occupiedSlots % CREATIVE_ROW_WIDTH;

        if (remainder == 0) {
            return occupiedSlots;
        }

        int padding = CREATIVE_ROW_WIDTH - remainder;

        for (int index = 0; index < padding; index++) {
            output.accept(
                    DecorItems.CREATIVE_SPACER.get().getDefaultInstance()
            );
        }

        return occupiedSlots + padding;
    }

    private static int addHeader(
            CreativeModeTab.Output output,
            DecorCategory category
    ) {
        for (DeferredItem<?> piece : DecorItems.creativeHeader(category)) {
            output.accept(piece.get().getDefaultInstance());
        }

        return CREATIVE_ROW_WIDTH;
    }

    public static void register(IEventBus bus) {
        TABS.register(bus);
    }
}

 '@

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_bobbleheads_0.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_bobbleheads_0"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_bobbleheads_0.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABAklEQVR4nK2SIauDYBSGn+9OhVk1DASzcWv+AP+BQRCEpXWLSZsG0/7HYGur/gQHK6sGm2FlyLR40+Um74TvPvVwXp5zeEEScTgcJpkA5X6/Sxl8SW3/R4AyN9jtdhRFAcAwDDweD/I8p+97PM8jCAJM0/xs4Ps+WZax3W5RVRXHcYjjmMvlguu68wY/nM9nANq2pa5r0jRlmiaOxyOmaX4O8H2f9/vN9XolDEMU5XfFMIxlT7QsCwBVVamqCiEE+/2e9Xq97IRxHLndbpxOJzRNoyxLoigiSRKE67qzTXy9XjRNA4AQAl3XsW2b1WrF8/mk67q/A5YgXSSx2WykDKT5BjHDUK5kdUCiAAAAAElFTkSuQmCC"

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_bobbleheads_1.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_bobbleheads_1"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_bobbleheads_1.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABFUlEQVR4nK2SMY6CUBRFzycgRhNq0OS3ttpZuAQr6FgApSvQDnbBCkgo2YAlhSa/saWgtiIKJsIUk5hMMkzz55YneffdvHdBUyKKokHHwFRKaSUwtKb/w0CUZTmkaYpSis1mQ5IkAHRdx+12I45jVqvVKDeUUhyPRyaTycc1CAJOpxPr9RrLsuj7fpSb5/MZ3/fxPI/3+w1AnucA1HXN5XJhsViMclMIAcAwDLRt+9nUti1FURCG4Z/c2O/3PB4PyrL8cZzlcgmAZVk0TTPKTSklh8OB+/3OdDr9RH29XlyvV7IsY7fbjXLhOM5g2zau6zKfz2mahqqqvl8kBLPZDCklz+fzVy62261WlfWL5LquVgJtfQGIzpQNOFylawAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_bobbleheads_2.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_bobbleheads_2"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_bobbleheads_2.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAA60lEQVR4nK2SLY6EQBCFPzaDAI0gIUFgEGBw3KMPAIJwGRRI7jAC05YD4DgAQSAImiAwrNgMOz+L6n1JmS/Vr151ChSl5Xl+qBjc+r5XSvCl9PpfDKSUBEFwgiiKkFKeVVXVC3/0ZllG0zTcAIZhYNs2TNM8jYQQdF0HgGEYRFHEcy/AcRw/Bn/pfr8D0LYtRVF8cIB936//QAiB67okScI0TR+8rmuA6wQAnue9rPXMLcv6NXjEWpaFsix5Z2maXg7RwjA8xnE8ga7rOI7DO/N9n3VdGcfxTDbPM1ocx0qnrHxImm3bSgmU9Q3+v1yTKue11gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_bobbleheads_3.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_bobbleheads_3"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_bobbleheads_3.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABZUlEQVR4nK2SLa/yAAyFn5FBsmWgJ/gKE1MIUFMIHIaELBgMDoFA8Rfgf2BwOMwUCkFwBDFByLYgELAlBE2veHN336t3m1T0tD3taQoZTZlMJpKFQD2dTpk2yGXq/gsCtdVqsVgsUuByuTCbzQAoFAqs12t0XWc6nRIEAd/1IsL7/UYNggAA13U5Ho8AaJqGZVk4joOmaSRJQrPZxPf9dNBwOOT5fP5I2Gw2RFHEarXCsiwAut0u5/OZ7XbLYDDg9XqlBCLC5/P5IXBdl2q1yng85na7USqVaLfbeJ7HbrfDNE1s2/6lX1EU1P+BRqOBrusAdDodVFVlPp+n+X6/z+FwSONKpQK9Xk/iOE7d931xHEf2+714nieGYYhhGLJcLiUMQxmNRhLHsTweD4miSJRisSi1Wo3vYwLk83ls2+Z6vZLL5ajX6wDc73eSJKFcLhOG4T8ZjuNkeuXMj6SYpplpg8z2Bdy4kqS5ku+pAAAAAElFTkSuQmCC"

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_bobbleheads_4.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_bobbleheads_4"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_bobbleheads_4.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABJklEQVR4nK2SscqCYABFj2JFLuESNjRLU4tDDg2thWPg2OQjhO/QC7g0+QgR9QiNEbTUlqIIroUa2v8C5fL9d7+HA/eCYCTXdT8iAOVyuQgZyELt/wBIh8Ph4/s+aZrS7XbxPI/xeExVVZxOJzabTbOBpmms12ve7zeWZWGaJrZtM5/Pud/vRFHUDNjv94xGI+q6JgxDqqrCcRxmsxm73Q5FUZoBrVYLgDzPuV6vrFYrHo8Hy+WS7XbLcDhsBti2ze12I4oiptMplmVxPp85Ho/0+32yLKOu658AJUkSPM+j0+nwer1YLBa4rktRFARBQBiGGIaBLH8fTOr1eh9VVRkMBrTbbZ7PJ3EcU5YlsiyjaRq6rv80kCaTidCVxY+k67qQgXD+AJJlbpV1/tT5AAAAAElFTkSuQmCC"

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_bobbleheads_5.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_bobbleheads_5"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_bobbleheads_5.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_bobbleheads_6.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_bobbleheads_6"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_bobbleheads_6.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_bobbleheads_7.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_bobbleheads_7"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_bobbleheads_7.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_bobbleheads_8.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_bobbleheads_8"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_bobbleheads_8.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_wall_decor_0.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_wall_decor_0"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_wall_decor_0.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABIklEQVR4nLWSscqCYBhGTyZfEG0h5tLQEha0CY1egORg1+AtdB9eQ9DY9l1CCBJIoLU1KA7SUkNEBP5XYA0f/9nfw4H3AUU6YRg2KgL9dDopFWhK1/8q2Gw2RFEEgO/7SClZLBZ0u132+z3r9RohRLsgyzImkwlVVWHbNo/Hg+FwiGVZ9Ho9pJTM5/N2QZ7naJqGbdvMZjN2ux2O4zCdTvl8PqRpiud56G2C6/XK8/lktVohhGC73SKl5P1+cz6fGQwGOI7TXtA0DZfLhSAISNOUsix5vV64rsvxeCQIAnRd//6FPM8RQhDHMf1+nyzLEEJwOBzwfZ8kSegsl8uvS6zrmrquMU0TwzAoioL7/c54POZ2u/0W/EJ5SJ3RaKRUoMwfo3JraVYCEOQAAAAASUVORK5CYII="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_wall_decor_1.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_wall_decor_1"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_wall_decor_1.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAA40lEQVR4nK2SMYqFQAyGf+VZCHOAgI2FoCAWdnMKwUsI9p7BI3gKSxmw8g5iYSXaWTkgKHaz1QqPtzyQ2UCKfCF/EhJA04wsy5SOwKvve60JTK3qfxGo6xpCCLiue8M4jiGEQBiGXxkAmLZtQ0qJKIpwXddbcpomnOf5lZnDMKBpGqRpin3fn6/Qti26rgMRwff9xwKvoijuIEkSVFX1TIExphhjqixLtSyL8jxP5Xmutm27fRzHPxnnXBlEpH4vsK4rpJQIggDHcWCe57uRZVlwHOeDGZxzrVfWfiSDiLQm0LYfn5FzdMh3Y5AAAAAASUVORK5CYII="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_wall_decor_2.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_wall_decor_2"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_wall_decor_2.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABN0lEQVR4nK2SoavCUBTGf3u6suSaDpWhoAgWkwPbupZhNxmNMqxj/4PVLEb/CLHJWBgKYpx1GIZ4X5B38aHp3felw4Hznd937wFFadPpVKgYFA+HgxLBl9L0fxgUf4per0cYhgghyLKMOI5ZLpdYlkUYhnLgeDwym80AGAwG7wTj8ZjRaIRpmsznc+73OwCe51Gv13Fdl9PpRKvVYrFYvBsIIXg8Hmy3WzqdDkI8P2mz2XC5XFitVjSbTfr9/u8Ir9I0DV3XAcjzXBLs93sASqWSXPbxEWu1GsPhkCRJuF6vst9oNOh2u1SrVXa73WeC9XrN7XYjiiJ838e2bRkBIE1TJpMJSZIQBAGa4zjyErMs43w+A1AoFDAMg0qlQp7nsg+g6zrtdvsZ99XgL1I+JK1cLisRKOsbHYlvDARoXA4AAAAASUVORK5CYII="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_wall_decor_3.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_wall_decor_3"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_wall_decor_3.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABp0lEQVR4nK2SMUs6cRzGPz87k7NsyKIDXWwTFyEkbwybpElDwanJXQchcLCh9e4N+AJaFHoLDRcSB3E4eNAQHhzBwbkVgfRt+ENv4P7P/DwPH3geSCjV7/clSYHmeV4iglSi9P8oUK7rSqFQII5jLMtiuVxyeXlJt9vl6OiIIAiYTqfs7Oxwf38PwNfXF47jYFkWKcdxME2T29tb4jimVCoxGAyYz+fU63U8z2M8HqNpGgDtdpu7uzsajQYHBwekJpMJIkIYhvi+z/n5OSKCbduk02menp7Y39/n8PDwD/v4+Jifnx+CIEADODk5QSlFLpdjd3f3z5jP51FKASDyb+3ZbAbAw8MD6/Wa1HA4JJvNcnZ2Rq1W4+XlBaUUNzc36LrO1dUVn5+f+L4PQKfTwbZtrq+vMU0Tnp+f5ePjQ1arlfR6PalUKjIajcR1XQnDUBaLhbRaLWk2mxLHsVxcXEi1WpXX11d5fHwUVS6XJYoivr+/0TSNYrHI3t4em82GKIrYbrdkMhkMw0BEeH9/5/T0FF3XeXt7Q9Xr9URXTn4kwzASESTWL+bvrNmQtEelAAAAAElFTkSuQmCC"

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_wall_decor_4.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_wall_decor_4"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_wall_decor_4.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAATElEQVR4nN3TsRHAQAgDQd54qIGQ6iiYKugAMruIy165dpRIBOZk5keAt6rQgge1LwFmhgGqygAzY8DuMqC7GRARDEBtETnujs6E8wPzjQ8LoueI8QAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_wall_decor_5.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_wall_decor_5"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_wall_decor_5.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_wall_decor_6.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_wall_decor_6"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_wall_decor_6.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_wall_decor_7.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_wall_decor_7"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_wall_decor_7.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_wall_decor_8.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_wall_decor_8"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_wall_decor_8.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_hanging_decor_0.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_hanging_decor_0"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_hanging_decor_0.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAA20lEQVR4nLWSMa5GUBCFPyISCpVCdQvtrahUErZgC2IFVmMNFBqJNeiEVpQanSg0/k73nj/v5p3qzEzm5GTmgCK0oihuFQFjHEclB7rS9r8KBEFA13VIKQHI85y2bZ+5aZrUdf3uYFkWzvME4L5v5nkGIIoiLMvCeBNomubh13U9PE1Tpml6d5BlGUIIqqp6eo7jEIYhfd9/d0Tf93Fd96njOMYwDMqy/NsXkiRhGAaEEGhRFP2YxOM4WNcV3/exbZtt29j3HSkly7Kg6/rvAt9AOUia53lKDpTxATBdQMSVUIGhAAAAAElFTkSuQmCC"

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_hanging_decor_1.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_hanging_decor_1"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_hanging_decor_1.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABcklEQVR4nK2SL8vycBSGr83X5BdYEBFRDGKwyGYTm0GwKOsimI2KxY9gcMkoCwoKMpAJVgWTYNBmExTmLP6D3962l6c+e+92Dvd9cR84EFBSs9n0ggD+7Pf7QA3kQOn/ArAsi3g8DkAul8OyLDqdDgC1Wo35fO6bVVVlMBgwm80Yj8c0Gg1kx3HIZrO8Xi/fWCgUiEQiAHiex+FwIJlM0u122e12aJqGruvcbjfkxWJBtVrl8Xj4ANu2abVafL9ff6dpGpIk0ev1EEIghMA0TeT1eo2iKKTTad88HA7J5/MkEokf93qehxACXddZLpesVivk0WgEQKVS4fl8AnC/35lMJpRKJT+83W4BaLfbbDYbDMPA8zzkWCyGYRiUy2U+n48fmE6nuK7rz6fTiX6/T7FYxDRN6vU6tm0jqarqAVwuFxzHIRqNcj6fSaVShMNhjscjQggymQwArutyvV55v9+EQqF/gN8q8CNJiqIEahBYfwHrI5nVLcs2dAAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_hanging_decor_2.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_hanging_decor_2"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_hanging_decor_2.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABSklEQVR4nK2SL6sCURDFf9c/ySImg0k0bbLt2sTvoGwXwSxYFIsfwaBdkA0KWiz7BRRMgkGD3K6I2xRh7ktv4eF76b6TZg4zhzOcAUuodrttbARSh8PBykHCavtfBCqVCpvNBsdx+K77/T4AjUaD9XodD7uuy3g8ZrVaMZ/PabVaJO73OwCXy4Xn8wlAtVolk8kAYIzheDxSKpUYDAbs93s8z8P3fW632+8nhGFIp9Ph/X7HnOd5KKUYDoeICCJCEASkcrnch8BkMmE2m2HMz4SNMYgIvu/T6/UQERJa6w+Bx+PBYrGgXq/H3G63A6Db7bLdbplOpxhj/k5huVwSRVHcn89nRqMRtVqNIAhoNpuEYYgqFAomm82itaZYLCIiaK0pl8uk02lOpxMiguM4AERRxPV65fV6kUwmUa7rWr2y9SOpfD5v5cAaX2KTjta5kMI2AAAAAElFTkSuQmCC"

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_hanging_decor_3.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_hanging_decor_3"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_hanging_decor_3.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABIklEQVR4nK2SMauCYBiFn8+ywK3NwBqcW9qc22sJ55ochZboD/Qf+g/i6Ox/CHMQh4YGa1UiCPzupFy5bt8928vhPTwHDihKeJ4nVQKG1+tViUBT+v6PgOHvY7lccj6fkVJSVRVpmnK5XHg+n63XKM9zfN9HK4riT6rrumw2GyaTCcfjke/323rb7Zb5fM5qtcIwjC5BIykldV0TRRGHw4G6rlsvDEMA4jimKAo00zR7uwkh0HUdgM/n01I0BLvdjrIs0W63W2/AbDZjvV6TZRmPx6Pj2bbNYrEgTdP+CkEQ8H6/SZKE0+nEeDxuaZoKr9eL/X6PsCxLWpbVPldVxf1+B2AwGGAYBtPplNFo1PEAdF1HOI6jNGXlIQnTNJUIlPUDSWRvVJNAQGsAAAAASUVORK5CYII="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_hanging_decor_4.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_hanging_decor_4"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_hanging_decor_4.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABlElEQVR4nK2Sv+txYRjGr+fbQRwsyBELq4Ukj0zKaKKoM5nOKgZFBgar8w/4F/gjDIQsJwObUid16pGSH0X3O3zL2zuf99rvz3Xd930BNsU0TSM7AMkwDFsJfmxN/w+AVCgUoKoqotEohBAYj8fY7XYolUqo1+sIBoM4nU6YTCYwDAPpdBqj0QgA8Hg88NPr9bBYLJDP59HtdiGEQDweR6vVwmw2A+cchmGg3+/D6XR+navVKobD4e8Kg8EARATTNHE4HJDL5UBE0HUdDocD8/kcXq8XkUgEn8/nCwmFQpCIfr8YDofBGIPP5/vHKRAIgDEGACAiPJ9PAMB0Ov17xHa7DY/Hg0wmg2w2i81mA8YYGo0G3G43yuUy7vc71uv1F1yr1aDrOtBsNmm5XNL5fKb9fk+qqlIymaROp0Pb7ZZM06TVakWVSoX8fj9pmkZCCCoWi5RKpYhxzul6vcKyLLxeL0iShFgsBlmWcblcYFkW3u83XC4XFEWBLMu43W44Ho9IJBJgnHNbVbZdJKYoiq0EtvUHDgGlL+7EpTgAAAAASUVORK5CYII="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_hanging_decor_5.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_hanging_decor_5"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_hanging_decor_5.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAi0lEQVR4nK3ToRXFIAwF0JdPsWgkhhkYgDHwVXVsxThoVHsOAltRFHSGH/p8bp5IgMXQvu9zBdhyzksNfkvTnwAxRhARH/DeQynFB8YYuK4Lz/PwgJQSzvOEEIIFUGtthhBw3zevQa0Vx3Gg985r4JybpRRIKWGM+RvYiAjWWtZ24INDIq310jMt5wXUTiktnJi66AAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_hanging_decor_6.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_hanging_decor_6"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_hanging_decor_6.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_hanging_decor_7.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_hanging_decor_7"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_hanging_decor_7.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_hanging_decor_8.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_hanging_decor_8"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_hanging_decor_8.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_small_decor_0.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_small_decor_0"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_small_decor_0.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABFklEQVR4nLWSMauCYBiFH8XFMYIPl0Z/QNCQuDcEjobQ4uQ/aHTod0RTQ5MQBJE/QohWF/ELJyexoSDv3bqTceGjs573PJwXDihKi6LoRwVgXK9XpQa6UvqrANM0Wa/XHA4HkiRhtVoBMB6POZ1ObDabzwDHcZhMJniex3w+J89zbrfb2xdCMBwOMfoAUkperxdBECCl5Hg8Yhh/52maslgs+hvkeU4YhpRlie/7bLdbRqPR29/v98xms36A67o4jsPlcuF8PiOEoK5ruq4DoKoqsizrf6FpGpbLJVEU8Xg82O12SCnfAIA4jtGm02nvEu/3O1VV8Xw+0XWdwWCAZVm0bUtRFNi2/RnwHykPSbMsS6mBsn4BJHtpptJA8U8AAAAASUVORK5CYII="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_small_decor_1.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_small_decor_1"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_small_decor_1.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABO0lEQVR4nK2SIavCUBiGn40paBjYFmQMi4IYpoZlFcPCwD+xX2DwpxhdFW3jwDCoUWxiVTC5NjDosGi653LhWu65b3z53vd7Ps4BRWlhGL5UCozD4aBEoCul/6VA0zSiKEIIQaPRAKBYLLJYLBBC4DgOAK7rIoSg2WzKsOu66N1ul0qlAsD5fOZ+v+N5HqVSiSzLaLVa5HkuQ18zkmA4HLLdbn9g9Xo9jscjcRwzGo243W6fT+h0Osznc2mYpkm73SZJEtbrNZZlUa/XPxYYq9WK6/UqjX6/j2EYjMdj6QVBwG63+51gMplQLpelMRgM2O/32LaNbdtMp1N83+f5fAKwXC7ZbDbMZjMANM/zXgCPx4PT6UStViNNU3Rdly+QpilZllGtVrlcLnJZoVD4LvirlD+SZlmWEoGy3mreasFGagHwAAAAAElFTkSuQmCC"

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_small_decor_2.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_small_decor_2"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_small_decor_2.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAA9ElEQVR4nK2SsYqDUBBFz4tRwc4qWliHoI2dP6Fd+lR+gqTze0Qs9UOClYVYWFk/HoGAbrXCsruw4e10M3funTtwQbNEnuebjsDx8XhoOThosf9FoOs6wjD8EYzjmK7raNuWqqooy5LT6fQFOwCM44hS6tcr1+uVLMtwXZeiKHi9Xu+9sG0b67rSti2Xy4V1Xd8TABBCYJomAM/nc3fxZ4EgCEjTlGEYmOd5nx8BmqYBYFkWbrfbN3Jd1yil6Pue+/2Obdu7GxFF0TZN075smibn83nvpZR84oZh4DgOvu9jWRZSSkSSJFpR1g6S8DxPy4F2fQDixlXHsADwwwAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_small_decor_3.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_small_decor_3"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_small_decor_3.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABpElEQVR4nK2Sz8o5cRjFz7z+hRkbU0ZEbCzYSU0pRZZKjYXMhg1LysKaG2BhO7fgGpSNkM0kzcKKmqam+UpqSqnnt3jrvYH5nf1zOs85H8CjuNFoRF4M/Lque0rw4+n6fxhwjDECgNvthvF4jGq1ClVVkUqlwBjDcrnE5XJBs9lEt9uFKIp4PB7QNA26rgP1ep14niee56nRaJDjOLRerymXy1G73SZFUajX65HjOLRYLCibzZKmaXS/36lWq5F/s9kAALbbLSzLAgDM53MIggDTNOG6LobDIYgIq9UKoihit9tBURQkk0n8dDodZDIZ9Pt9vN9vEP2umkgk4PP5IAgCgsHg38/xeBwcxwEAiOi3xHw+j1KphOv1CgCYTqeIRCIol8uoVCo4nU7gOA6DwQDhcBitVguu6+J4PAKMMWKMkWEYJMsyTSYT2u/3ZFkWGYZBqqpSsVik2WxG5/OZTNOkw+FAiqJQLBYjjuf5PxIDgQAKhQJerxds28bn84Hf70c6nUY0GsXz+YRt2/h+vwiFQpAkCZwsy55Q9g6SJEmeEnjWP/vPuRZHFjurAAAAAElFTkSuQmCC"

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_small_decor_4.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_small_decor_4"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_small_decor_4.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAA1UlEQVR4nK2QMY5GUBRGjz8/odFJlKLQ66gtgViCyiYUWrahUdmDBagVQmIFEprHVPN3k3mTN193i3vu+S4oRiuK4lEBvKdpUjJ4KW3/B+AdhiF1XQNwnifjONI0Dc8j95qPQZqmVFVFkiTYti1t8BJCfAbHcbjvm23bOM9TrsJ1XQD0fQ9A13Ws60oQBH+rkOc5bduSZRlxHGMYhhzANE0AhBAMw8C+75RlybfZb9GiKHqO42BZFnzfx7Is5nlG13U8z5MDSJ36qYLKMoDmuq6SgXK+ANhCR/VLbxrxAAAAAElFTkSuQmCC"

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_small_decor_5.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_small_decor_5"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_small_decor_5.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_small_decor_6.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_small_decor_6"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_small_decor_6.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_small_decor_7.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_small_decor_7"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_small_decor_7.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_small_decor_8.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_small_decor_8"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_small_decor_8.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_furniture_0.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_furniture_0"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_furniture_0.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAA0ElEQVR4nLWSPQqEQAyFv1msBHsLq2m1mc5e8AJeQTyKB7DyDmJrJXgAOw8gFnaDndgIs9vZLPvHsA9C4IW8PJKAJURRFHcbAWeaJisHN6vuvwoopei67oqqqi4uDEMAyrLE+TQhyzLGcQQgSRIA5nnmOA6AzwJt2wIwDAN93z/Vf3KQpikAQogrf7VEKSVRFHGeJ8YYlFJ4nkcQBL9dQWtNXdfkeU7TNKzriojj+OUn7vvOsixIKXFd9+K3bUNrjTHmvcA3sH4k4fu+lQNrPABJm0vkQkod2wAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_furniture_1.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_furniture_1"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_furniture_1.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABQUlEQVR4nK2SL8vCUBSHnyteQQZLigaTYDLZ5uo+grKPIAg2o8kuiGkfwGLYwhBW/BaCQRAdCmYFg3/wXttg4U33PfHhnIff4RwwLDEYDLSJoLjdbo0SFIym/0Uwm80A6HQ6JElCkiREUcR4PEYIkfHJZAKA7/vEcZzNFJ7PJ8fjMTP2ej2m0yme52HbdsZd18WyLAC01ux2u79XqFarKKW4XC68Xi8ANpsNw+GQz+eT6y0qpXIgiiIAVqsV5/MZ13UBCIKA5XKJ1vmrF06nE0KIDPi+z3w+p9/v0+12kVICcLvdCMMQz/PygsViQalUysD3+2W9XnO9XhmNRrzf71y6+/2eE4haraYbjQZSSh6PB2ma0mw2KZfLHA4HpJRUKhXSNKXVaiGlZL/fo5Si3W4jHMcxemXjRxL1et0ogXH9AH0ue5gBiy5lAAAAAElFTkSuQmCC"

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_furniture_2.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_furniture_2"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_furniture_2.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABE0lEQVR4nK2SsYrCQBCGvxUVErCUWARBsRFs7PYRfA9F8F1s7NKmSuE7WPkEQtrVQrQIbhVCmuxcZeDgOA/2BoYZmJmPf4YBT1Pb7VZ8AN3L5eKloOM1/R8ArLWyXq/l8XiItfabp2kq77rWWk6nk5zPZ9Fay263E2utdACMMaxWK2azGQD7/Z7xeEyWZbzrVVUBUNc1xpifV5jP520eRRGTyeTjBr/eoGkaAJRSbXTO/R3wfD5xzrFcLhkMBsRxzPV6bYEfAUVRkCQJm82G4/HI/X7ncDjQ7/fbHrVYLOR2uzGdTgnDEBEhz3OiKGI4HALwer0oigLnHEEQEMcxvV6PsixRWmuvV/Z+JDUajbwUeNsXWBx/DIYjuPwAAAAASUVORK5CYII="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_furniture_3.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_furniture_3"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_furniture_3.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABEklEQVR4nK2Soc6CYBSGH51fgDlH0M3ADBCsRCHqJbB5CSbkHghUr0GahRm4ARLFRoaNwWa0Ot2Av5HU8v2nvu95znu2FyRndDgcehnAJM9zqQRjqe3/AIwej0f/fD7JsozT6YRlWYRhOBiKosD3/e8JXNclCAJ2ux2z2WwQXNdltVqx3W4py/L3C4vFgq7raJqG1+sFQBzH1HVNFEWYpvkVMInjGIDL5UJd1ziOMyS43W4AaJqGruufAfv9Htu2OR6PXK9XhBCDaBgGqqp+vQ4wbtuWJEm43+94nsf7/R5eSNOU8/n8EzCaTqe9YRgoikJRFAghmM/nVFU1mIQQrNfrz4DNZiNVZfkiLZdLqQTS8wcN6VrGlQuQhgAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_furniture_4.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_furniture_4"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_furniture_4.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_furniture_5.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_furniture_5"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_furniture_5.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_furniture_6.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_furniture_6"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_furniture_6.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_furniture_7.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_furniture_7"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_furniture_7.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_furniture_8.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_furniture_8"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_furniture_8.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_lighting_0.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_lighting_0"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_lighting_0.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAp0lEQVR4nLWSoQ2EQBBF31zAUAEJqLUo3ArqoQrcVrCFYOlgG0ChyGo0we45zIXjwuS+m5+Zlz/JB6Wk7/ukAWTzPKsSvFTXfwW0bcs0TTRNc+lZa+8TrOvKcRwfXl3XDMPw/IWu6xCR5wARIaX0HBBCACC7WxzHEYBt2/Den/6yLDjnEGvtZRP3fSfGeM55nlNVFTFGjDEURfEd8IvURZKyLFUJ1HoDHQoz2jrt6FwAAAAASUVORK5CYII="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_lighting_1.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_lighting_1"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_lighting_1.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABN0lEQVR4nK2SMarCUBBFT6JVsBSSQlIEQUI28Cxdg1VaBcHa3hW4AJEsII0LCLoAQSvBNljJEzWVClpkfhewSPX+hYFhuHO4DAOGsiaTiZgAmsfj0SiBbbT9HwD2+71orSXPc0mSRJRSMp1OpSgKGY/HopSSJEnker3K5XKRoih+yj4cDvT7feI45n6/o7Wu4Hme836/ARARer0e3W4XgMVige/7NOfzOY7jUJYlaZr+pFuv11X//X4BCMOwmrmui12WJXEck2UZ2+0Wz/Mqw3A4xPd9VqtV7Qns2WzGbrdjuVwiIpxOpx9DEAS02+1aQHMwGDAajXi9Xmw2m1pjnawwDOV2u/H5fGg0GrRaLTqdDs/nk/P5TBAEOI6D1prH40EURVVS13WxlFJGr2z8SJbneUYJjPUHJNmTAk0GRFMAAAAASUVORK5CYII="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_lighting_2.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_lighting_2"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_lighting_2.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABSklEQVR4nK2SIYsCURSFvzdqEsxmwTQW22gTwWZVpotgFiyKxeAPmOB0QSYoaLHMHzBYtFlkugZHDIpw3wbBDYsb9u1Jt9zDd869YCjVbre1iUFyv98bEVhG2/9iUK/XKRaLrNdrbNt+z/1+H4BGo8FqtQLAcRw8z2O5XDKbzWi1Wljj8Zjr9QrA8Xjkfr8DUC6XSafTAGitsSyLwWDAdrulVCrhui7n8xmrUCiQyWR+oIVhSKfT4fl8AlCr1VBKMRwOERFEhCAISH7KNplMmE6naP26slIKrTUiguu69Ho9RORziZfLhfl8TrVafRMBdLtdNpsNvu+/ov3W8GKxII5jAHa7HaPRiEqlQhAENJtNwjBEOY6jAW63G1EUkcvlEBGiKCKfz5NKpTgcDogItm0TxzGn04nH40Eikfg2+KuMH0lls1kjAmN9AUKijza8xoaBAAAAAElFTkSuQmCC"

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_lighting_3.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_lighting_3"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_lighting_3.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAATUlEQVR4nM3TsQ3AMAwDQdpIr5aF5vPAArSDtkiG+CJmzwMbSjDrnPMS4KkqtGCj9h3AzPy8wDYDupsBqC1pRwQDMpMBqC1p2UZnwvkAXu4MC1RgRwEAAAAASUVORK5CYII="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_lighting_4.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_lighting_4"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_lighting_4.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_lighting_5.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_lighting_5"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_lighting_5.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_lighting_6.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_lighting_6"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_lighting_6.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_lighting_7.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_lighting_7"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_lighting_7.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_lighting_8.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_lighting_8"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_lighting_8.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_outdoor_decor_0.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_outdoor_decor_0"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_outdoor_decor_0.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABFUlEQVR4nLWToY6DUBBFz9uUkqYYUgM/QNI0IUGQoKqQiCYIbBUe3x9ANantP4BDVVUWxwdgWtcQHIr2rdp17G7yslfPnMyd3AuKEmmaShXArGkapQs+lLb/HRCGIefzmbIsOZ1OuK4LgOd5VFXFZrOZBqzXa7IsoygKgiCgaRoOhwPz+fx7pm3baYDv+0gpOR6PaJrG9XrFMAxs2+b1ev3NwpdWqxVCCACklAzDAIAQYhpQ1zVCCPb7PYvFgiiKGIaB2+3G4/Hg/X7jeR4iCILJIG23W5IkwbZt7vc7eZ5zuVxwHIfdbkccxz8DAPq+5/l8Mo4juq5jWRbL5RKAruuY/ebfNE1M05z8jXKQhGVZSmVS1ieFkFbwD0rGiAAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_outdoor_decor_1.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_outdoor_decor_1"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_outdoor_decor_1.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABPklEQVR4nK2SMYrCUBRFz1MTVFC0kBiIFqJFwMJK3ETssgWXIG7A2NhY6R5SWbgRUUEbLUSwlRAs5H+LgYFhYGbgz61e8e7hXrhgKBmNRtoEkNtut0YJMkbu/wDkAKIowrZtWq0W+Xz+y8NyueR6vTKdTtFakyQJh8OB1WrF/X4nk6YpAM/nk16vR7vdBmA+n9NsNpnNZjweDwDCMGQ4HFKtVhmPx3Q6ne8VfN//vB3HodvtUi6XAdBao5Ris9ng+z79fv8DICIopf7UWUSwLAuA1+tFplQq4Xke5/MZEfkV0Gg0CIKA0+nEer0mF8cxx+ORxWKBbds/muM4Jk1Tdrsdk8mE2+2GVCoVrZSiUCjgeR6WZaG1Zr/f4zgOtVoNgCRJuFwuAGSzWYrFIq7rIoPBwGjKxkOSer1ulMBYb0wLac1rtyqkAAAAAElFTkSuQmCC"

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_outdoor_decor_2.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_outdoor_decor_2"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_outdoor_decor_2.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABGUlEQVR4nK2SMarCUBBFzxOjSMQmFnEJliEpXitYWhnQ1iq9jZWttRvIFswirEzAJisQhDSB2IgIKvOLj9XnVe+f9jDDneGCJSpJErFZ0C7L0ipBy2r6Pxa0p9Mpy+WS4XDI9XolTVO+Z5lcEATsdrvfBOv1mizL0FpTliXb7ZZOp8N4PMbkvsRxTEtE2O/3OI7D8Xik3+8zGo0IwxCT+3w+f3/geR5KKQBEhNfrhck9n08ADocDLaUUq9WKXq/HbDbj8XhQFAWn0wmT+7JYLGCz2cj5fJaqqiTPc5nP5zIYDCSKIjG5JEmkaRqZTCaitNZyu92o65r3+02328X3fVzXBcDk7vc7l8sFpbW2qrJ1kZTv+1YJrPkBW6OifkYClLkAAAAASUVORK5CYII="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_outdoor_decor_3.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_outdoor_decor_3"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_outdoor_decor_3.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABOklEQVR4nK2SParCQBSFvyQvES0CFoIWQlobwU7r1NpEt5DKTkhvkdaUcQ1KKnELLsDCQizEX+wDBoSZ1408tJt3249z7rmXA5pjhGEodQx+ttutVgJTS/0fBsb1epWbzYbZbIaU73d0Oh3iOEZKSZ7n7HY75vM5j8dDMQBzOp3i+z6u637dMBqNGAwGVKtVoiji9XopFgQBZq1WQwjB+Xzm+Xx+GEgpEUKwXq9ptVoIIRTLsgxzMpmwWCw4nU5YlvX9TsPAtm0AiqJQKYIgwEyShOFwSK/Xw3GcrwbNZpN+v89+v+dyufxh5mq14na7MR6PKYriQ7xcLknTlPv9ThiGlEollSbLMox2uy3L5TKHwwHbtvE8T4nzPOd4PAJgWRaVSoVGo4HjOIoZ3W5Xq8r6RarX61oJtOcXBQV9abkKwKoAAAAASUVORK5CYII="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_outdoor_decor_4.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_outdoor_decor_4"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_outdoor_decor_4.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABpUlEQVR4nK2SvWoyYRBGz/qL608TQYMimMZCGwmSFTuxtDKFYKOVpaJFQLHwCvQGbLyBXESKSCI2i8gKqSKIILwigkQwTArhu4H9nn7OnGEesBmt2WyKHYDLNE1bBg5b0/8DoCml5Ovri1arRaFQoFarEYvFUEoxGo1YLpeUSiWq1SrhcJjNZsNkMsE0TbLZLI5EIkGxWETXdfr9Pu/v7+TzeXq9HkopkskknU6H19dXDMPANE0GgwEej+d2wvf3N9PplOfnZwCGwyEiwna7Zb1e8/T0hIgwHo9xu928vb0RCAS4v7/n9/f3ZlCv1zmdTojcPhqJRHA6nQSDwX+bAO7u7tA0DQAR4efnB8fDwwOZTIbVagVAt9tF13UeHx/J5XLM53M0TaPRaODz+SiXy5zPZz4/P29UpZRYliWGYUi73ZbZbCa73U4sy5JarSbpdFpeXl5ksVjIdruVj48PqVQqEgqFpNlsihYIBATA7XaTSqU4Ho/s93sulwsul4t4PI7f7+dwOLDf77ler3i9XqLRKH6/H80wDFtVtl+kaDRqy8B2/gD0OqtpKE5+WAAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_outdoor_decor_5.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_outdoor_decor_5"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_outdoor_decor_5.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAwklEQVR4nK2SMQ5FQBRFjx8kGp1EKQqVBVBbArEElU3YANvQqOzBAtQKIVFqR8P87tcj82//Ts59uaAZo6oqqQMw53nWMvhoXf8DYJznKQGEEEzTRNu2SKn+lg9Anuc0TUOWZbiu+8rgV8HzPJ7nYd93hBDKABNgGAYA+r5n2zaiKHpnUJYlXddRFAVpmmLb9jvAfd+M48hxHNR1zXVdygAjjmO5rithGOI4DsuyYFkWQRCoAZIk0Zqy/pB839cy0M4XuExAom7ORhgAAAAASUVORK5CYII="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_outdoor_decor_6.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_outdoor_decor_6"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_outdoor_decor_6.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_outdoor_decor_7.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_outdoor_decor_7"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_outdoor_decor_7.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_header_outdoor_decor_8.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_header_outdoor_decor_8"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_header_outdoor_decor_8.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAALklEQVR4nGNgoBAwpqWl/afEAJZLly5R5AIminSPGjBqwKAxgFFCQoKizEQxAADykQYLeKUo7gAAAABJRU5ErkJggg=="

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/creative_spacer.json" `
@'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_spacer"
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/creative_spacer.png" `
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAEklEQVR4nGNgGAWjYBSMAggAAAQQAAFVN1rQAAAAAElFTkSuQmCC"


Write-Host ""
Write-Host "Creative category header rows installed."
Write-Host "Backup directory: $BackupRoot"
Write-Host ""
Write-Host "Building..."
Write-Host ""

& .\gradlew.bat build

if ($LASTEXITCODE -ne 0) {
    throw "Build failed. Original files are available in: $BackupRoot"
}

Write-Host ""
Write-Host "Build successful."
Write-Host "Open the Droingo's Decor creative tab to see the Bobbleheads header."
