$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$ProjectRoot = (Get-Location).Path
$BackupRoot = Join-Path $ProjectRoot (".overlay_poc_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))

function Backup-File {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $Target = Join-Path $ProjectRoot $RelativePath

    if (Test-Path -LiteralPath $Target) {
        $Backup = Join-Path $BackupRoot $RelativePath
        $BackupDirectory = Split-Path -Parent $Backup

        New-Item -ItemType Directory -Force -Path $BackupDirectory | Out-Null
        Copy-Item -LiteralPath $Target -Destination $Backup -Force
    }
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Content
    )

    Backup-File $RelativePath

    $Target = Join-Path $ProjectRoot $RelativePath
    $Directory = Split-Path -Parent $Target

    New-Item -ItemType Directory -Force -Path $Directory | Out-Null
    [System.IO.File]::WriteAllText($Target, $Content, $Utf8NoBom)
}

function Write-Base64File {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Base64
    )

    Backup-File $RelativePath

    $Target = Join-Path $ProjectRoot $RelativePath
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
    "src/main/java/net/droingo/decor/content/overlay/OverlayItem.java" `
@'
package net.droingo.decor.content.overlay;

import net.droingo.decor.DroingosDecor;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.Display;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemDisplayContext;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.context.UseOnContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.AABB;

import java.util.List;

/**
 * Proof-of-concept wall overlay.
 *
 * The visual is a vanilla ItemDisplay entity anchored to a supporting block
 * face. It occupies no block space, has no collision and therefore remains
 * when fences, torches, pipes or other partial blocks are placed in front.
 */
public final class OverlayItem extends Item {
    public static final String OVERLAY_MARKER =
            DroingosDecor.MOD_ID + "_overlay";

    public static final String SUPPORT_X =
            DroingosDecor.MOD_ID + "_overlay_support_x";

    public static final String SUPPORT_Y =
            DroingosDecor.MOD_ID + "_overlay_support_y";

    public static final String SUPPORT_Z =
            DroingosDecor.MOD_ID + "_overlay_support_z";

    public static final String SUPPORT_FACE =
            DroingosDecor.MOD_ID + "_overlay_support_face";

    public static final String OVERLAY_ID =
            DroingosDecor.MOD_ID + "_overlay_id";

    private static final double FACE_OFFSET = 0.5015D;

    private final ResourceLocation overlayId;

    public OverlayItem(String id, Properties properties) {
        super(properties);

        overlayId = ResourceLocation.fromNamespaceAndPath(
                DroingosDecor.MOD_ID,
                id
        );
    }

    @Override
    public InteractionResult useOn(UseOnContext context) {
        Direction face = context.getClickedFace();

        if (!face.getAxis().isHorizontal()) {
            return InteractionResult.PASS;
        }

        Level level = context.getLevel();
        BlockPos supportPos = context.getClickedPos();

        if (level.getBlockState(supportPos).isAir()) {
            return InteractionResult.FAIL;
        }

        if (level.isClientSide) {
            return InteractionResult.SUCCESS;
        }

        ServerLevel serverLevel = (ServerLevel) level;

        /*
         * One overlay per supporting block face. Placing another overlay on
         * the same face replaces the old one.
         */
        removeExistingOverlay(
                serverLevel,
                supportPos,
                face
        );

        Display.ItemDisplay display =
                EntityType.ITEM_DISPLAY.create(serverLevel);

        if (display == null) {
            return InteractionResult.FAIL;
        }

        double x =
                supportPos.getX()
                        + 0.5D
                        + face.getStepX() * FACE_OFFSET;

        double y =
                supportPos.getY() + 0.5D;

        double z =
                supportPos.getZ()
                        + 0.5D
                        + face.getStepZ() * FACE_OFFSET;

        display.setPos(x, y, z);
        display.setYRot(yawForFace(face));
        display.setXRot(0.0F);
        display.setNoGravity(true);
        display.setBillboardConstraints(
                Display.BillboardConstraints.FIXED
        );
        display.setItemTransform(ItemDisplayContext.FIXED);
        display.setItemStack(new ItemStack(this));

        CompoundTag persistentData =
                display.getPersistentData();

        persistentData.putBoolean(OVERLAY_MARKER, true);
        persistentData.putInt(SUPPORT_X, supportPos.getX());
        persistentData.putInt(SUPPORT_Y, supportPos.getY());
        persistentData.putInt(SUPPORT_Z, supportPos.getZ());
        persistentData.putString(
                SUPPORT_FACE,
                face.getName()
        );
        persistentData.putString(
                OVERLAY_ID,
                overlayId.toString()
        );

        serverLevel.addFreshEntity(display);

        if (
                context.getPlayer() == null
                        || !context.getPlayer()
                        .getAbilities()
                        .instabuild
        ) {
            context.getItemInHand().shrink(1);
        }

        return InteractionResult.CONSUME;
    }

    public static void removeExistingOverlay(
            ServerLevel level,
            BlockPos supportPos,
            Direction face
    ) {
        AABB searchBox = new AABB(supportPos).inflate(1.1D);

        List<Display.ItemDisplay> displays =
                level.getEntitiesOfClass(
                        Display.ItemDisplay.class,
                        searchBox,
                        display -> isOverlayFor(
                                display,
                                supportPos,
                                face
                        )
                );

        for (Display.ItemDisplay display : displays) {
            display.discard();
        }
    }

    public static boolean isOverlayFor(
            Display.ItemDisplay display,
            BlockPos supportPos,
            Direction face
    ) {
        CompoundTag data = display.getPersistentData();

        if (!data.getBoolean(OVERLAY_MARKER)) {
            return false;
        }

        return data.getInt(SUPPORT_X) == supportPos.getX()
                && data.getInt(SUPPORT_Y) == supportPos.getY()
                && data.getInt(SUPPORT_Z) == supportPos.getZ()
                && data.getString(SUPPORT_FACE)
                .equals(face.getName());
    }

    public static boolean isOverlay(
            Display.ItemDisplay display
    ) {
        return display.getPersistentData()
                .getBoolean(OVERLAY_MARKER);
    }

    public static BlockPos getSupportPos(
            Display.ItemDisplay display
    ) {
        CompoundTag data = display.getPersistentData();

        return new BlockPos(
                data.getInt(SUPPORT_X),
                data.getInt(SUPPORT_Y),
                data.getInt(SUPPORT_Z)
        );
    }

    private static float yawForFace(Direction face) {
        return switch (face) {
            case SOUTH -> 0.0F;
            case WEST -> 90.0F;
            case NORTH -> 180.0F;
            case EAST -> -90.0F;
            default -> 0.0F;
        };
    }
}
'@

Write-Utf8NoBom `
    "src/main/java/net/droingo/decor/content/overlay/OverlayEvents.java" `
@'
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
'@

Write-Host "Patching DecorCategory.java..."

$CategoryRelative = "src/main/java/net/droingo/decor/api/DecorCategory.java"
$CategoryPath = Join-Path $ProjectRoot $CategoryRelative
$Category = [System.IO.File]::ReadAllText($CategoryPath)

if ($Category -notmatch "\bOVERLAYS\b") {
    $Category = [regex]::Replace(
        $Category,
        '(?s)(OUTDOOR_DECOR\s*\([^)]*\))',
        '$1,`r`n    OVERLAYS(100)'
    )
}

Backup-File $CategoryRelative
[System.IO.File]::WriteAllText(
    $CategoryPath,
    $Category,
    $Utf8NoBom
)

Write-Host "Patching DecorPlacementType.java..."

$PlacementRelative = "src/main/java/net/droingo/decor/api/DecorPlacementType.java"
$PlacementPath = Join-Path $ProjectRoot $PlacementRelative
$Placement = [System.IO.File]::ReadAllText($PlacementPath)

if ($Placement -notmatch "\bOVERLAY\b") {
    $Placement = [regex]::Replace(
        $Placement,
        ';\s*$',
        ',`r`n    OVERLAY;'
    )
}

Backup-File $PlacementRelative
[System.IO.File]::WriteAllText(
    $PlacementPath,
    $Placement,
    $Utf8NoBom
)

Write-Host "Patching DecorItems.java..."

$ItemsRelative = "src/main/java/net/droingo/decor/registry/DecorItems.java"
$ItemsPath = Join-Path $ProjectRoot $ItemsRelative
$Items = [System.IO.File]::ReadAllText($ItemsPath)

if ($Items -notmatch 'content\.overlay\.OverlayItem') {
    $Items = $Items.Replace(
        "import net.droingo.decor.content.WallDecorItem;",
        "import net.droingo.decor.content.WallDecorItem;`r`nimport net.droingo.decor.content.overlay.OverlayItem;"
    )

    if ($Items -notmatch 'content\.overlay\.OverlayItem') {
        $Items = $Items.Replace(
            "import net.droingo.decor.content.TinyDecorItem;",
            "import net.droingo.decor.content.TinyDecorItem;`r`nimport net.droingo.decor.content.overlay.OverlayItem;"
        )
    }
}

if ($Items -notmatch "\bMOSSY_BOTTOM\b") {
    $Registrations = @'

    public static final DeferredItem<Item> MOSSY_BOTTOM = ITEMS.register(
            "mossy_bottom",
            () -> new OverlayItem(
                    "mossy_bottom",
                    new Item.Properties()
            )
    );

    public static final DeferredItem<Item> WET_BOTTOM = ITEMS.register(
            "wet_bottom",
            () -> new OverlayItem(
                    "wet_bottom",
                    new Item.Properties()
            )
    );

    public static final List<DeferredItem<Item>> OVERLAYS_HEADER =
            registerHeader("overlays");
'@

    $Items = $Items.Replace(
        "    private DecorItems()",
        $Registrations + "`r`n    private DecorItems()"
    )
}

if ($Items -notmatch 'case\s+OVERLAYS\s*->') {
    $Items = [regex]::Replace(
        $Items,
        '(case\s+OUTDOOR_DECOR\s*->\s*OUTDOOR_DECOR_HEADER;)',
        '$1`r`n            case OVERLAYS -> OVERLAYS_HEADER;'
    )
}

Backup-File $ItemsRelative
[System.IO.File]::WriteAllText(
    $ItemsPath,
    $Items,
    $Utf8NoBom
)

Write-Host "Patching DecorDefinitionRegistry.java..."

$DefinitionsRelative = "src/main/java/net/droingo/decor/registry/DecorDefinitionRegistry.java"
$DefinitionsPath = Join-Path $ProjectRoot $DefinitionsRelative
$Definitions = [System.IO.File]::ReadAllText($DefinitionsPath)

if ($Definitions -notmatch 'ResourceLocation\s+mossyBottomId') {
    $OverlayDefinitions = @'

        ResourceLocation mossyBottomId = id("mossy_bottom");

        register(
                DecorDefinition.builder(mossyBottomId)
                        .category(DecorCategory.OVERLAYS)
                        .placement(DecorPlacementType.OVERLAY)
                        .item(DecorItems.MOSSY_BOTTOM::get)
                        .build()
        );

        ResourceLocation wetBottomId = id("wet_bottom");

        register(
                DecorDefinition.builder(wetBottomId)
                        .category(DecorCategory.OVERLAYS)
                        .placement(DecorPlacementType.OVERLAY)
                        .item(DecorItems.WET_BOTTOM::get)
                        .build()
        );
'@

    $Definitions = $Definitions.Replace(
        "    public static DecorDefinition register(DecorDefinition definition)",
        $OverlayDefinitions + "`r`n    public static DecorDefinition register(DecorDefinition definition)"
    )
}

Backup-File $DefinitionsRelative
[System.IO.File]::WriteAllText(
    $DefinitionsPath,
    $Definitions,
    $Utf8NoBom
)

Write-Host "Patching creative category labels..."

$ScreenRelative = "src/main/java/net/droingo/decor/client/creative/CreativeCategoryScreenEvents.java"
$ScreenPath = Join-Path $ProjectRoot $ScreenRelative
$Screen = [System.IO.File]::ReadAllText($ScreenPath)

if ($Screen -notmatch 'labels\.put\(\s*"overlays"') {
    $Screen = $Screen.Replace(
        '        labels.put("outdoor_decor", Component.literal("Outdoor Decor"));',
        '        labels.put("outdoor_decor", Component.literal("Outdoor Decor"));`r`n        labels.put("overlays", Component.literal("Overlays"));'
    )

    if ($Screen -notmatch 'labels\.put\(\s*"overlays"') {
        $Screen = $Screen.Replace(
            '        return Map.copyOf(labels);',
            '        labels.put("overlays", Component.literal("Overlays"));`r`n`r`n        return Map.copyOf(labels);'
        )
    }
}

Backup-File $ScreenRelative
[System.IO.File]::WriteAllText(
    $ScreenPath,
    $Screen,
    $Utf8NoBom
)

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/mossy_bottom.json" `
@'
{
  "credit": "Made with Blockbench",
  "texture_size": [
    32,
    32
  ],
  "textures": {
    "0": "droingos_decor:item/mossy_bottom",
    "particle": "droingos_decor:item/mossy_bottom"
  },
  "elements": [
    {
      "from": [
        0,
        0,
        8
      ],
      "to": [
        16,
        16,
        8
      ],
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            16,
            16
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            0,
            16,
            16
          ],
          "texture": "#0"
        }
      }
    }
  ],
  "display": {
    "thirdperson_righthand": {
      "rotation": [
        0,
        90,
        0
      ],
      "translation": [
        0,
        2.5,
        1
      ],
      "scale": [
        0.375,
        0.375,
        0.375
      ]
    },
    "thirdperson_lefthand": {
      "rotation": [
        0,
        90,
        0
      ],
      "translation": [
        0,
        2.5,
        1
      ],
      "scale": [
        0.375,
        0.375,
        0.375
      ]
    },
    "firstperson_righthand": {
      "rotation": [
        0,
        90,
        0
      ],
      "translation": [
        0,
        1,
        0
      ],
      "scale": [
        0.5,
        0.5,
        0.5
      ]
    },
    "firstperson_lefthand": {
      "rotation": [
        0,
        90,
        0
      ],
      "translation": [
        0,
        1,
        0
      ],
      "scale": [
        0.5,
        0.5,
        0.5
      ]
    },
    "ground": {
      "translation": [
        0,
        3,
        0
      ],
      "scale": [
        0.5,
        0.5,
        0.5
      ]
    },
    "gui": {
      "rotation": [
        0,
        180,
        0
      ],
      "scale": [
        0.8,
        0.8,
        0.8
      ]
    },
    "fixed": {
      "rotation": [
        0,
        180,
        0
      ],
      "scale": [
        2.0,
        2.0,
        2.0
      ]
    }
  }
}
'@

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/wet_bottom.json" `
@'
{
  "credit": "Made with Blockbench",
  "texture_size": [
    32,
    32
  ],
  "textures": {
    "0": "droingos_decor:item/wet_bottom",
    "particle": "droingos_decor:item/wet_bottom"
  },
  "elements": [
    {
      "from": [
        0,
        0,
        8
      ],
      "to": [
        16,
        16,
        8
      ],
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            16,
            16
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            0,
            16,
            16
          ],
          "texture": "#0"
        }
      }
    }
  ],
  "display": {
    "thirdperson_righthand": {
      "rotation": [
        0,
        90,
        0
      ],
      "translation": [
        0,
        2.5,
        1
      ],
      "scale": [
        0.375,
        0.375,
        0.375
      ]
    },
    "thirdperson_lefthand": {
      "rotation": [
        0,
        90,
        0
      ],
      "translation": [
        0,
        2.5,
        1
      ],
      "scale": [
        0.375,
        0.375,
        0.375
      ]
    },
    "firstperson_righthand": {
      "rotation": [
        0,
        90,
        0
      ],
      "translation": [
        0,
        1,
        0
      ],
      "scale": [
        0.5,
        0.5,
        0.5
      ]
    },
    "firstperson_lefthand": {
      "rotation": [
        0,
        90,
        0
      ],
      "translation": [
        0,
        1,
        0
      ],
      "scale": [
        0.5,
        0.5,
        0.5
      ]
    },
    "ground": {
      "translation": [
        0,
        3,
        0
      ],
      "scale": [
        0.5,
        0.5,
        0.5
      ]
    },
    "gui": {
      "rotation": [
        0,
        180,
        0
      ],
      "scale": [
        0.8,
        0.8,
        0.8
      ]
    },
    "fixed": {
      "rotation": [
        0,
        180,
        0
      ],
      "scale": [
        2.0,
        2.0,
        2.0
      ]
    }
  }
}
'@

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/mossy_bottom.png" `
    "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAADqUlEQVR4AcxWTW8bNxCdJYe7K8ko2saJHcP9CJBTrvkD/rn9HUVRtGgPRXtsYqunwHFqqUJTSbskp+9ts4JSNIeCygfBx+EMyXlvKGJtJ++5fRACKlzCPuC+3u89mJ3sRfb3cr639P+nvAEmoSXGOe1/ZWOccHIhfoCUNSePxcujV+D8QiiEINGQ/fnVy+vjL6b35WLYp/JQ9Mu56PkTCVLY3Pm16NnyFZ5JYOJBEMlkEFOBw+Vgnmsnv0s49lKvVOq/2gMI2MxEN1PRNZLR/tlIIMlQ3SNReQw8lJB6CyTdTiR0LyX0638ghc0hkcaNaNyKYj4kJwmrO07S3F1L86lIU1WbRR/lLNWiuRWf65kShfziUkB1KnUCcpCQm/osKqoDGSvdrqSmMBIHrX3uZ77dTsMkmifKBWxB6ieh6duQYS0FzSAwX+tQaSunNhFHYk2mTZdDrs2nkJUoFmBHbairXOephdpZCG1aBtefWu9OLM58LUfVBLbts3Y+uEzyaJqxN3u8Dylr7qizWqOFAX2uFb45Ua3Soo3Za9qqJXOpre7l3Kt50+CsnuHMDPulsLkcTX0lNaFOAoSoOlWKiD6edIb7yeYsdXebyi2mPQQn04gzhBQ2Z9POd9585pU6XC2u1eP+xSDHizPrhms3wzzj9av41BjeC/Y6C4X8SJrEW+59l1RzFjVD7SBTkme7IybVAO+rkHETeTijFjUYzhQLqJIkE5DIWqKI9bLf3CdV718w0oj8Gn2+wzlhEiuC8xK4xaX8srqUH1Zz+f6Py/7H5bz/6eYqfn37dP3tat59tXy2+W0538xvnm6f3FzGb55fdT+/wL7bef8dUULOs47DO0YFvh3epYAdKQSQl/Ac4L/1PpJ7MI1Qzg8lYP8/JuR9rf+bnMQ7HEoAGd8kggL2qyY5vx+0+NjwaBlIfP2GFCyQ5CTbkWLvGDuIAFY4goT3QUC7I4FPAfSJU/i03OM4wC/qJGcefrCYmCAhKybOkZ0+49zH/TswgPWiXuP0ZwDJSETLGD6eQiywdgZwjSJGcs4P8hPgCy4fgWACkJyggBH098lZNMkpbkIH54o6/z58jAwPAFbK5CSlANoxRi6u8QYYo4CGQZwr6vyNN8hwBDApqyUxHyNF0CfIRXJaxrk30MG5os4cJJwiywxogc8BzgnGCcZoRxxMAB8ZRbDKMTlFkIB2BN/IuE7BvIWDPEIUO/RbjBTC35kWrlQYxmtnjEBIEgYi/g0AAP//nuPM9gAAAAZJREFUAwBgdUlPGKaemwAAAABJRU5ErkJggg=="

Write-Base64File `
    "src/main/resources/assets/droingos_decor/textures/item/wet_bottom.png" `
    "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAABiklEQVR4AezVSUsDQRAF4LiviODBBRX8/3dBES8iKIj/QxC9elDwfcSCQUiiPYIQJtSbWrqr3uuegSyO/vnXImAhmrtI2m6/EdAl1QdL7dTjTkPG0fRnkSMsLKdFHNduJWB/yojv5Ii7mNI6e6kE2DlJBAFOCkW8koaKE7YbAYifJoywXsRd0qoRMaH1Z2UETliQH6aV75IgksNB1nl7IGm7GYCcf84YgwGhE8Nx6nJ1++zvIsvtZuBq2k8CZIh4tbXU4DX+KLBGRJGL1bLUbgS8p30n2AiQAwEFOSKEyPWIidOTtnYzbC/tu8FZ4KSGIyWAr5q91ohQIwDS1m6GesdvGbEdGOi0iH2MRMjBXuS8ur32pa3dDAODNjNmK1gPTgMxqIMaX/gzAT4yIpyyhhOBgC9437VOsFvQE63thri6XxLIvWc+6ciVg7yg/pEH+IATtpuht2m/CfjL+OvgKhDfx59/4SL+Mai1u8QPQS8joNeAvs2DgOEGhhsYbmC4geEG5v8GZv1bfgIAAP//XXnotQAAAAZJREFUAwCXtxpB5xLROwAAAABJRU5ErkJggg=="

Write-Host "Creating the transparent Overlays category header models..."

$MarkerModel = @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@

for ($Index = 0; $Index -lt 9; $Index++) {
    Write-Utf8NoBom `
        "src/main/resources/assets/droingos_decor/models/item/creative_header_overlays_$Index.json" `
        $MarkerModel
}

Write-Host "Patching language file..."

$LangRelative = "src/main/resources/assets/droingos_decor/lang/en_us.json"
$LangPath = Join-Path $ProjectRoot $LangRelative
$Lang = @{}

if (Test-Path -LiteralPath $LangPath) {
    $ExistingText = [System.IO.File]::ReadAllText($LangPath)

    if (![string]::IsNullOrWhiteSpace($ExistingText)) {
        $ExistingObject = $ExistingText | ConvertFrom-Json

        foreach ($Property in $ExistingObject.PSObject.Properties) {
            $Lang[$Property.Name] = $Property.Value
        }
    }
}

$Lang["item.droingos_decor.mossy_bottom"] = "Mossy Bottom"
$Lang["item.droingos_decor.wet_bottom"] = "Wet Bottom"

$OrderedLang = [ordered]@{}

foreach ($Key in ($Lang.Keys | Sort-Object)) {
    $OrderedLang[$Key] = $Lang[$Key]
}

Write-Utf8NoBom `
    $LangRelative `
    ($OrderedLang | ConvertTo-Json -Depth 6)

Write-Host ""
Write-Host "Overlay proof of concept installed."
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
Write-Host ""
Write-Host "Test:"
Write-Host "1. Place Mossy Bottom or Wet Bottom on a vertical wall face."
Write-Host "2. Place a fence or other partial block in the air block in front."
Write-Host "3. Confirm the overlay remains visible."
