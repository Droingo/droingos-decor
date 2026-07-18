$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Root = (Get-Location).Path
$BackupRoot = Join-Path $Root (".buddy_bobblehead_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))

function Backup-File {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $Target = Join-Path $Root $RelativePath

    if (Test-Path -LiteralPath $Target) {
        $Backup = Join-Path $BackupRoot $RelativePath
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Backup) | Out-Null
        Copy-Item -LiteralPath $Target -Destination $Backup -Force
    }
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Content
    )

    Backup-File $RelativePath

    $Target = Join-Path $Root $RelativePath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Target) | Out-Null
    [System.IO.File]::WriteAllText($Target, $Content, $Utf8NoBom)
}

if (!(Test-Path -LiteralPath (Join-Path $Root "build.gradle"))) {
    throw "Run this script from the Droingo's Decor project root."
}

# ---------------------------------------------------------------------------
# Register Buddy item
# ---------------------------------------------------------------------------

$ItemsRelative = "src/main/java/net/droingo/decor/registry/DecorItems.java"
$ItemsPath = Join-Path $Root $ItemsRelative

if (!(Test-Path -LiteralPath $ItemsPath)) {
    throw "Missing file: $ItemsRelative"
}

Backup-File $ItemsRelative
$Items = [System.IO.File]::ReadAllText($ItemsPath)

if (!$Items.Contains("BUDDY_BOBBLEHEAD")) {
    $Pattern = '(?ms)(public\s+static\s+final\s+DeferredItem<Item>\s+(?:PUMPKIN_BOBBLE|BOBBLE_PARROT)\s*=\s*ITEMS\.register\([\s\S]*?\n\s*\);)'

    if (!([regex]::IsMatch($Items, $Pattern))) {
        throw "Could not find an existing bobblehead item registration."
    }

    $Registration = @'

    public static final DeferredItem<Item> BUDDY_BOBBLEHEAD = ITEMS.register(
            "buddy_bobblehead",
            () -> new TinyDecorItem(
                    "buddy_bobblehead",
                    new Item.Properties()
            )
    );
'@

    $Items = [regex]::Replace(
            $Items,
            $Pattern,
            '$1' + $Registration,
            1
    )
}

[System.IO.File]::WriteAllText($ItemsPath, $Items, $Utf8NoBom)

# ---------------------------------------------------------------------------
# Register Buddy definition and right-click behaviour
# ---------------------------------------------------------------------------

$DefinitionsRelative = "src/main/java/net/droingo/decor/registry/DecorDefinitionRegistry.java"
$DefinitionsPath = Join-Path $Root $DefinitionsRelative

if (!(Test-Path -LiteralPath $DefinitionsPath)) {
    throw "Missing file: $DefinitionsRelative"
}

Backup-File $DefinitionsRelative
$Definitions = [System.IO.File]::ReadAllText($DefinitionsPath)

if (!$Definitions.Contains('ResourceLocation buddyId = id("buddy_bobblehead");')) {
    $Anchor = '        ResourceLocation sweaterId = id("hanging_sweater");'

    if (!$Definitions.Contains($Anchor)) {
        throw "Could not find the hanging_sweater registration anchor."
    }

    $Registration = @'
        ResourceLocation buddyId = id("buddy_bobblehead");

        register(
                DecorDefinition.builder(buddyId)
                        .category(DecorCategory.BOBBLEHEADS)
                        .placement(DecorPlacementType.TINY)
                        .item(DecorItems.BUDDY_BOBBLEHEAD::get)
                        .bounds(
                                -0.145D,
                                0.0D,
                                -0.20D,
                                0.145D,
                                0.52D,
                                0.20D
                        )
                        .bobblehead(
                                new BobbleheadRenderDefinition(
                                        model("buddy_bobble_body"),
                                        model("buddy_bobble_head"),
                                        new Vector3d(
                                                7.7D / 16.0D,
                                                2.4D / 16.0D,
                                                7.4D / 16.0D
                                        ),
                                        1.5F
                                )
                        )
                        .interaction((level, pos, player, container, slot) -> {
                            if (level.isClientSide) {
                                net.droingo.decor.client.animation
                                        .BobbleheadInteractionPulses
                                        .trigger(container, slot);
                            } else {
                                /*
                                 * Use the normal wolf ambient sound, pitched
                                 * upward to read as a young puppy.
                                 */
                                float pitch =
                                        1.45F
                                                + level.random.nextFloat()
                                                * 0.30F;

                                level.playSound(
                                        null,
                                        pos,
                                        net.minecraft.sounds.SoundEvents.WOLF_AMBIENT,
                                        SoundSource.BLOCKS,
                                        0.85F,
                                        pitch
                                );
                            }

                            return net.minecraft.world.InteractionResult
                                    .sidedSuccess(level.isClientSide);
                        })
                        .build()
        );

'@

    $Definitions = $Definitions.Replace(
            $Anchor,
            $Registration + $Anchor
    )
}

[System.IO.File]::WriteAllText(
        $DefinitionsPath,
        $Definitions,
        $Utf8NoBom
)

# ---------------------------------------------------------------------------
# Models and texture
# ---------------------------------------------------------------------------

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/block/buddy_bobble_body.json" `
@'
{
  "parent": "minecraft:block/block",
  "textures": {
    "1": "droingos_decor:block/buddy_bobblehead",
    "particle": "droingos_decor:block/buddy_bobblehead"
  },
  "elements": [
    {
      "from": [
        6.75,
        -0.1,
        6.75
      ],
      "to": [
        9.25,
        0.4,
        9.25
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          8.25,
          -0.1,
          8.25
        ]
      },
      "faces": {
        "north": {
          "uv": [
            9,
            11,
            11.5,
            11.5
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            11,
            9,
            13.5,
            9.5
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            11,
            10,
            13.5,
            10.5
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            2,
            12,
            4.5,
            12.5
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            2.5,
            8.5,
            0,
            6
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            8.5,
            0,
            6,
            2.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7,
        0,
        7
      ],
      "to": [
        9,
        0.5,
        9
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          0,
          7
        ]
      },
      "faces": {
        "north": {
          "uv": [
            12,
            2,
            14,
            2.5
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            12,
            3,
            14,
            3.5
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            5,
            12,
            7,
            12.5
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            12,
            7,
            14,
            7.5
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            5,
            8,
            3,
            6
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            8,
            3,
            6,
            5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.2,
        2.2,
        6.8
      ],
      "to": [
        8.7,
        3.7,
        8.8
      ],
      "rotation": {
        "angle": 45,
        "axis": "x",
        "origin": [
          6.7,
          1.7,
          6.8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            11,
            0,
            12.5,
            1.5
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            2,
            10,
            4,
            11.5
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            11,
            4,
            12.5,
            5.5
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            10,
            2,
            12,
            3.5
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            5.5,
            12,
            4,
            10
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            1.5,
            11,
            0,
            13
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        8.8,
        1.7,
        6.8
      ],
      "to": [
        8.8,
        3.7,
        8.8
      ],
      "rotation": {
        "angle": 45,
        "axis": "x",
        "origin": [
          6.8,
          1.7,
          6.8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            8,
            3,
            10,
            5
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            5,
            8,
            7,
            10
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            0,
            2,
            0,
            0
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.1,
        1.7,
        6.8
      ],
      "to": [
        7.1,
        3.7,
        8.8
      ],
      "rotation": {
        "angle": 45,
        "axis": "x",
        "origin": [
          5.1,
          1.7,
          6.8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            0,
            9,
            2,
            11
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            9,
            0,
            11,
            2
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            0,
            2,
            0,
            0
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.7,
        3.7,
        8.3
      ],
      "to": [
        8.2,
        4.7,
        8.8
      ],
      "rotation": {
        "angle": 45,
        "axis": "x",
        "origin": [
          6.7,
          1.7,
          6.8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            13,
            12,
            13.5,
            13
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            13,
            13,
            13.5,
            14
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            14,
            0,
            14.5,
            1
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            14,
            1,
            14.5,
            2
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            14.5,
            2.5,
            14,
            2
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            14.5,
            3,
            14,
            3.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.3,
        0.1,
        7.3
      ],
      "to": [
        7.8,
        2.1,
        7.8
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          6.7,
          1.7,
          6.8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            9,
            12,
            9.5,
            14
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            10,
            12,
            10.5,
            14
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            11,
            12,
            11.5,
            14
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            12,
            11,
            12.5,
            13
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            14.5,
            5.5,
            14,
            5
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            6.5,
            14,
            6,
            14.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.3,
        0.5,
        7.7
      ],
      "to": [
        7.8,
        1,
        9.2
      ],
      "rotation": {
        "angle": 22.5,
        "axis": "y",
        "origin": [
          6.7,
          1.5,
          8.8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            14,
            6,
            14.5,
            6.5
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            12,
            8,
            13.5,
            8.5
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            7,
            14,
            7.5,
            14.5
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            13,
            4,
            14.5,
            4.5
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            5.5,
            14.5,
            5,
            13
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            13.5,
            5,
            13,
            6.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        8.3,
        0.5,
        7.1
      ],
      "to": [
        8.8,
        1,
        8.6
      ],
      "rotation": {
        "angle": -22.5,
        "axis": "y",
        "origin": [
          7.7,
          1.5,
          8.2
        ]
      },
      "faces": {
        "north": {
          "uv": [
            14,
            7,
            14.5,
            7.5
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            6,
            13,
            7.5,
            13.5
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            14,
            8,
            14.5,
            8.5
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            13,
            11,
            14.5,
            11.5
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            8.5,
            14.5,
            8,
            13
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            12.5,
            13,
            12,
            14.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        8.1,
        0.1,
        7.3
      ],
      "to": [
        8.6,
        2.1,
        7.8
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          6.7,
          1.7,
          6.8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            13,
            0.5,
            15
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            13,
            0,
            13.5,
            2
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            1,
            13,
            1.5,
            15
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            2,
            13,
            2.5,
            15
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            9.5,
            14.5,
            9,
            14
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            14.5,
            9,
            14,
            9.5
          ],
          "texture": "#1"
        }
      }
    }
  ]
}
'@

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/block/buddy_bobble_head.json" `
@'
{
  "parent": "minecraft:block/block",
  "textures": {
    "1": "droingos_decor:block/buddy_bobblehead",
    "particle": "droingos_decor:block/buddy_bobblehead"
  },
  "elements": [
    {
      "from": [
        7.7,
        4.4,
        7.2
      ],
      "to": [
        8.7,
        5.4,
        7.2
      ],
      "rotation": {
        "angle": 22.5,
        "axis": "z",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            6,
            5,
            7,
            6
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            1
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            2,
            9,
            3,
            10
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            1
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            1,
            0,
            0,
            0
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            1,
            0,
            0,
            0
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.26976,
        4.65475,
        7.2
      ],
      "to": [
        8.26976,
        5.65475,
        7.2
      ],
      "rotation": {
        "angle": -22.5,
        "axis": "z",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            9,
            2,
            10,
            3
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            1
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            10,
            4,
            11,
            5
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            1
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            1,
            0,
            0,
            0
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            1,
            0,
            0,
            0
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7,
        2.6,
        6.5
      ],
      "to": [
        9,
        4.6,
        8
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            5,
            6,
            7,
            8
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            9,
            5,
            10.5,
            7
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            7,
            5,
            9,
            7
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            7,
            9,
            8.5,
            11
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            11,
            8.5,
            9,
            7
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            11,
            9,
            9,
            10.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        6.5,
        2.2,
        6.8
      ],
      "to": [
        9.5,
        5.2,
        6.8
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            3,
            3
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            0,
            3,
            3,
            6
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            3,
            0,
            0,
            0
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            3,
            0,
            0,
            0
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        6.5,
        2.2,
        7.7
      ],
      "to": [
        9.5,
        5.2,
        7.7
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            3,
            0,
            6,
            3
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            3,
            3,
            6,
            6
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            3,
            0,
            0,
            0
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            3,
            0,
            0,
            0
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.5,
        2.6,
        5.9
      ],
      "to": [
        8.5,
        3.6,
        7.4
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            6,
            10,
            7,
            11
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            6,
            11,
            7.5,
            12
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            7,
            12,
            8,
            13
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            11,
            6,
            12.5,
            7
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            12,
            8.5,
            11,
            7
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            9,
            11,
            8,
            12.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.7,
        3.15,
        5.8
      ],
      "to": [
        8.2,
        3.65,
        7.3
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            14,
            14,
            14.5,
            14.5
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            10,
            14,
            11.5,
            14.5
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            0,
            15,
            0.5,
            15.5
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            14,
            10,
            15.5,
            10.5
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            14.5,
            13.5,
            14,
            12
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            13.5,
            14,
            13,
            15.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.2,
        3.6,
        6.4
      ],
      "to": [
        7.7,
        4.1,
        7.9
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            14,
            14,
            14.5,
            14.5
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            10,
            14,
            11.5,
            14.5
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            0,
            15,
            0.5,
            15.5
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            14,
            10,
            15.5,
            10.5
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            14.5,
            13.5,
            14,
            12
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            13.5,
            14,
            13,
            15.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        8.2,
        3.6,
        6.4
      ],
      "to": [
        8.7,
        4.1,
        7.9
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            14,
            14,
            14.5,
            14.5
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            10,
            14,
            11.5,
            14.5
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            0,
            15,
            0.5,
            15.5
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            14,
            10,
            15.5,
            10.5
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            14.5,
            13.5,
            14,
            12
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            13.5,
            14,
            13,
            15.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7,
        2,
        6.1
      ],
      "to": [
        9,
        4,
        6.1
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            7,
            7,
            9,
            9
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            3,
            8,
            5,
            10
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            2,
            0,
            0,
            0
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            2,
            0,
            0,
            0
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.7,
        3.31146,
        6.02326
      ],
      "to": [
        8.2,
        3.31146,
        7.52326
      ],
      "rotation": {
        "angle": -22.5,
        "axis": "x",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0.5,
            0
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            0,
            0,
            1.5,
            0
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            0,
            0,
            0.5,
            0
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            0,
            0,
            1.5,
            0
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            3.5,
            14.5,
            3,
            13
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            4.5,
            13,
            4,
            14.5
          ],
          "texture": "#1"
        }
      }
    }
  ]
}
'@

Write-Utf8NoBom `
    "src/main/resources/assets/droingos_decor/models/item/buddy_bobblehead.json" `
@'
{
  "parent": "minecraft:block/block",
  "textures": {
    "1": "droingos_decor:block/buddy_bobblehead",
    "particle": "droingos_decor:block/buddy_bobblehead"
  },
  "elements": [
    {
      "from": [
        6.75,
        -0.1,
        6.75
      ],
      "to": [
        9.25,
        0.4,
        9.25
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          8.25,
          -0.1,
          8.25
        ]
      },
      "faces": {
        "north": {
          "uv": [
            9,
            11,
            11.5,
            11.5
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            11,
            9,
            13.5,
            9.5
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            11,
            10,
            13.5,
            10.5
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            2,
            12,
            4.5,
            12.5
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            2.5,
            8.5,
            0,
            6
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            8.5,
            0,
            6,
            2.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7,
        0,
        7
      ],
      "to": [
        9,
        0.5,
        9
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7,
          0,
          7
        ]
      },
      "faces": {
        "north": {
          "uv": [
            12,
            2,
            14,
            2.5
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            12,
            3,
            14,
            3.5
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            5,
            12,
            7,
            12.5
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            12,
            7,
            14,
            7.5
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            5,
            8,
            3,
            6
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            8,
            3,
            6,
            5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.7,
        4.4,
        7.2
      ],
      "to": [
        8.7,
        5.4,
        7.2
      ],
      "rotation": {
        "angle": 22.5,
        "axis": "z",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            6,
            5,
            7,
            6
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            1
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            2,
            9,
            3,
            10
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            1
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            1,
            0,
            0,
            0
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            1,
            0,
            0,
            0
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.26976,
        4.65475,
        7.2
      ],
      "to": [
        8.26976,
        5.65475,
        7.2
      ],
      "rotation": {
        "angle": -22.5,
        "axis": "z",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            9,
            2,
            10,
            3
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            1
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            10,
            4,
            11,
            5
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            1
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            1,
            0,
            0,
            0
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            1,
            0,
            0,
            0
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7,
        2.6,
        6.5
      ],
      "to": [
        9,
        4.6,
        8
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            5,
            6,
            7,
            8
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            9,
            5,
            10.5,
            7
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            7,
            5,
            9,
            7
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            7,
            9,
            8.5,
            11
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            11,
            8.5,
            9,
            7
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            11,
            9,
            9,
            10.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        6.5,
        2.2,
        6.8
      ],
      "to": [
        9.5,
        5.2,
        6.8
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            3,
            3
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            0,
            3,
            3,
            6
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            3,
            0,
            0,
            0
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            3,
            0,
            0,
            0
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        6.5,
        2.2,
        7.7
      ],
      "to": [
        9.5,
        5.2,
        7.7
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            3,
            0,
            6,
            3
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            3,
            3,
            6,
            6
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            3
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            3,
            0,
            0,
            0
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            3,
            0,
            0,
            0
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.5,
        2.6,
        5.9
      ],
      "to": [
        8.5,
        3.6,
        7.4
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            6,
            10,
            7,
            11
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            6,
            11,
            7.5,
            12
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            7,
            12,
            8,
            13
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            11,
            6,
            12.5,
            7
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            12,
            8.5,
            11,
            7
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            9,
            11,
            8,
            12.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.7,
        3.15,
        5.8
      ],
      "to": [
        8.2,
        3.65,
        7.3
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            14,
            14,
            14.5,
            14.5
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            10,
            14,
            11.5,
            14.5
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            0,
            15,
            0.5,
            15.5
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            14,
            10,
            15.5,
            10.5
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            14.5,
            13.5,
            14,
            12
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            13.5,
            14,
            13,
            15.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.2,
        3.6,
        6.4
      ],
      "to": [
        7.7,
        4.1,
        7.9
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            14,
            14,
            14.5,
            14.5
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            10,
            14,
            11.5,
            14.5
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            0,
            15,
            0.5,
            15.5
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            14,
            10,
            15.5,
            10.5
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            14.5,
            13.5,
            14,
            12
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            13.5,
            14,
            13,
            15.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        8.2,
        3.6,
        6.4
      ],
      "to": [
        8.7,
        4.1,
        7.9
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            14,
            14,
            14.5,
            14.5
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            10,
            14,
            11.5,
            14.5
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            0,
            15,
            0.5,
            15.5
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            14,
            10,
            15.5,
            10.5
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            14.5,
            13.5,
            14,
            12
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            13.5,
            14,
            13,
            15.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7,
        2,
        6.1
      ],
      "to": [
        9,
        4,
        6.1
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            7,
            7,
            9,
            9
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            3,
            8,
            5,
            10
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            2,
            0,
            0,
            0
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            2,
            0,
            0,
            0
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.7,
        3.31146,
        6.02326
      ],
      "to": [
        8.2,
        3.31146,
        7.52326
      ],
      "rotation": {
        "angle": -22.5,
        "axis": "x",
        "origin": [
          7.7,
          2.4,
          7.4
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0.5,
            0
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            0,
            0,
            1.5,
            0
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            0,
            0,
            0.5,
            0
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            0,
            0,
            1.5,
            0
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            3.5,
            14.5,
            3,
            13
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            4.5,
            13,
            4,
            14.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.2,
        2.2,
        6.8
      ],
      "to": [
        8.7,
        3.7,
        8.8
      ],
      "rotation": {
        "angle": 45,
        "axis": "x",
        "origin": [
          6.7,
          1.7,
          6.8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            11,
            0,
            12.5,
            1.5
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            2,
            10,
            4,
            11.5
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            11,
            4,
            12.5,
            5.5
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            10,
            2,
            12,
            3.5
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            5.5,
            12,
            4,
            10
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            1.5,
            11,
            0,
            13
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        8.8,
        1.7,
        6.8
      ],
      "to": [
        8.8,
        3.7,
        8.8
      ],
      "rotation": {
        "angle": 45,
        "axis": "x",
        "origin": [
          6.8,
          1.7,
          6.8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            8,
            3,
            10,
            5
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            5,
            8,
            7,
            10
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            0,
            2,
            0,
            0
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.1,
        1.7,
        6.8
      ],
      "to": [
        7.1,
        3.7,
        8.8
      ],
      "rotation": {
        "angle": 45,
        "axis": "x",
        "origin": [
          5.1,
          1.7,
          6.8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            0,
            9,
            2,
            11
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            9,
            0,
            11,
            2
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            0,
            2,
            0,
            0
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            0,
            0,
            0,
            2
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.7,
        3.7,
        8.3
      ],
      "to": [
        8.2,
        4.7,
        8.8
      ],
      "rotation": {
        "angle": 45,
        "axis": "x",
        "origin": [
          6.7,
          1.7,
          6.8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            13,
            12,
            13.5,
            13
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            13,
            13,
            13.5,
            14
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            14,
            0,
            14.5,
            1
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            14,
            1,
            14.5,
            2
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            14.5,
            2.5,
            14,
            2
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            14.5,
            3,
            14,
            3.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.3,
        0.1,
        7.3
      ],
      "to": [
        7.8,
        2.1,
        7.8
      ],
      "rotation": {
        "angle": 0,
        "axis": "x",
        "origin": [
          6.7,
          1.7,
          6.8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            9,
            12,
            9.5,
            14
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            10,
            12,
            10.5,
            14
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            11,
            12,
            11.5,
            14
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            12,
            11,
            12.5,
            13
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            14.5,
            5.5,
            14,
            5
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            6.5,
            14,
            6,
            14.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        7.3,
        0.5,
        7.7
      ],
      "to": [
        7.8,
        1,
        9.2
      ],
      "rotation": {
        "angle": 22.5,
        "axis": "y",
        "origin": [
          6.7,
          1.5,
          8.8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            14,
            6,
            14.5,
            6.5
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            12,
            8,
            13.5,
            8.5
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            7,
            14,
            7.5,
            14.5
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            13,
            4,
            14.5,
            4.5
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            5.5,
            14.5,
            5,
            13
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            13.5,
            5,
            13,
            6.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        8.3,
        0.5,
        7.1
      ],
      "to": [
        8.8,
        1,
        8.6
      ],
      "rotation": {
        "angle": -22.5,
        "axis": "y",
        "origin": [
          7.7,
          1.5,
          8.2
        ]
      },
      "faces": {
        "north": {
          "uv": [
            14,
            7,
            14.5,
            7.5
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            6,
            13,
            7.5,
            13.5
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            14,
            8,
            14.5,
            8.5
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            13,
            11,
            14.5,
            11.5
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            8.5,
            14.5,
            8,
            13
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            12.5,
            13,
            12,
            14.5
          ],
          "texture": "#1"
        }
      }
    },
    {
      "from": [
        8.1,
        0.1,
        7.3
      ],
      "to": [
        8.6,
        2.1,
        7.8
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          6.7,
          1.7,
          6.8
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            13,
            0.5,
            15
          ],
          "texture": "#1"
        },
        "east": {
          "uv": [
            13,
            0,
            13.5,
            2
          ],
          "texture": "#1"
        },
        "south": {
          "uv": [
            1,
            13,
            1.5,
            15
          ],
          "texture": "#1"
        },
        "west": {
          "uv": [
            2,
            13,
            2.5,
            15
          ],
          "texture": "#1"
        },
        "up": {
          "uv": [
            9.5,
            14.5,
            9,
            14
          ],
          "texture": "#1"
        },
        "down": {
          "uv": [
            14.5,
            9,
            14,
            9.5
          ],
          "texture": "#1"
        }
      }
    }
  ],
  "display": {
    "thirdperson_righthand": {
      "rotation": [
        17.48,
        38.28,
        6.25
      ],
      "translation": [
        -1.5,
        7.25,
        4
      ]
    },
    "thirdperson_lefthand": {
      "rotation": [
        17.48,
        38.28,
        6.25
      ],
      "translation": [
        -1.5,
        7.25,
        4
      ]
    },
    "firstperson_righthand": {
      "rotation": [
        -180,
        53.5,
        180
      ],
      "translation": [
        1.5,
        11.5,
        0
      ],
      "scale": [
        1.35547,
        1.35547,
        1.35547
      ]
    },
    "firstperson_lefthand": {
      "rotation": [
        -180,
        53.5,
        -180
      ],
      "translation": [
        1.5,
        11.5,
        0
      ],
      "scale": [
        1.35547,
        1.35547,
        1.35547
      ]
    },
    "ground": {
      "translation": [
        0,
        4.75,
        0
      ]
    },
    "gui": {
      "rotation": [
        -155.25,
        48.25,
        -180
      ],
      "translation": [
        0,
        13,
        0
      ],
      "scale": [
        2.52148,
        2.52148,
        2.52148
      ]
    },
    "fixed": {
      "translation": [
        0,
        7.5,
        0
      ],
      "scale": [
        1.62891,
        1.62891,
        1.62891
      ]
    }
  }
}
'@

$TexturePath = Join-Path $Root "src/main/resources/assets/droingos_decor/textures/block/buddy_bobblehead.png"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $TexturePath) | Out-Null
[System.IO.File]::WriteAllBytes(
        $TexturePath,
        [Convert]::FromBase64String("iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAHFklEQVR4AayWeWzUVRDH3/uV7bl1d1sLRdSGaBRFPMGo8UDjXx4oongAioJHxGhUPCKXgmJEJNHIKacgCIoggvqHQSAgRhFEQMBoOEq0LW23y3a7bXe3z/eZ7mt2W4gxoel3Z97MO2bmzcz7eep//k0aMcC88uAAM/7h68zYoVeaaU8NNGxRVtbDhEKlBlpe3stUVPTuAPo+ffrKvEAgKBQZOKUBbgGTHJBpX4Gqa21RlQ1hVRoKqJr6E6JOpVJKa53mkyoajQqam5tFVl9fJ7StLet85fXo0TNbYqeVlpaZAwf2te9mx+4fWTKZVK2trYoD4/G4Yow+lUpaGUhZmlI+n0+ALhOel+2zV139T5eDrNUjT2YYMjwLhUKyZ35+viosLBSen0ikQWNIfX2tZl8HdCUlpRCVm5sr1P14eOsGjvr9/sUsdmNHkTX7uqlEIiEb5eUYoeg5nCvKzy9QGOpy4Mm7+5ox915m7romqB4ZdJHpEoG6uuM6GCwxbAIwiIMyZcgBurmrdulZK3bohWv26hdnb9avL9wiEeTwcLheNTU1CWwUWaLmrt2nZ36+W7+zeJtesm6/REYU6R8P2tBQL5vAYxA0U8YYoBs0/Dlz36iXzW0PjBFK1pP9dXW1qq2tTa4ELzGE63py6BVm+O0XmDdG3WSeG9zPDHl0bIez7CkGwHRG797nZ01Ej5fc4bln9VJ9L+wjyUgSpmwFOBC9SCSso9GIJheI2LINf+hJCzbr99fs0asXTe9wlj09NoXJBLJDh/7MmoieKmhpaVGENxKJqLy8PCm9bt262cynApKKtcw9++xzjQNjIlVefpYBjB08NnUDR5GdKgL5NvMPVR5VTbYX4HVra/PAVCqpIrYCWN9g+wMHY2hTUwyR4Pjxal1V9bdABOkf75xzKk4a6lNFYM+2DerrT2fqbd+sUDs3rVVlZeWbSkrOVBjcs2cvVVBQqI4dO6o9rz2AiUSrHOXufv3eI1nneZWVR7QLGzPhiQCUcSbwLB5vkjCzcWfgtZtfXV1lc6DOZn1VuyVpxR2XVGSNvSmPXmsGX+VXE0deL1n6wNVFMnXYDd3VjKcHmmlPXG/GDRtgqG2ttXiIESQfB8bT3ZAxBsli+0NEiG5nR5BZdce/F47G1fHmuKptaVYFeT4Va0mJsra2VsVbEkrn+JQxRppPUZFfdJQXDGXnsy0XHrQb1ATbBS77iXim0iOpOIBMDgQCqri4WPS2G0pdNzY2qpycHJHHbfiBz3ZDEoq+AAXBYEiqgn3wngpho9v75aqXH7nOEOmJD11uuncvz86BhG2rLAqHwypuw5myNc3CBnuYz3rHwxMoLrKlF0fcAQ6pSD+5hLmxMaqIAEikE4/J7322S09b8oOesGi7nrz8V11Tk50TXlWsUV4tvDSJuMJjFs607fPVeVv02yt367GzNurc3DyJCEbCUyVHjhzSgKT1+4slAngOH7P7FtkrwzgH9i23vQDq4C1df1B/+MlPevGXv+spK3ZrLEbJIijI5DmAjZFnAiMoPwDPXUMzwXyuC+rgcSdkpgMKDmQhPMjkGeMdV0BZMhcZNBOjh1xqnhl2tRl1Tz9DhU15/Ga5e9cPWAPkLeDeHNiYboayM/AKmaPw3D20pqZahe1rCODnr/5NIrvgiz168uKtesJH30v9u2pgDRADYBxsS5VHJhAISe1T/3hGMjKH8DNua0tJ0iEDfr9fhUIlkgfwI+640Dx8Zx/DazhuxLVm8uj2b8eioiLD+sapUyUiXo3NSu7VUaoAsGnCVgjgqYUiw+O4rZBo9ARD2x/aW+3Ro4c1VwUF5NbHXx3QvIZvLd2uJ87fJBGIxWIyz//aazL2KCW8gxJa+oLsbH8wxB1MSVqR8ttsp9/b3FE8MHFbusXFZ5gxDw2Q+35s8CXytfzS/VeJh3jLOnIMHjB2kCvg48EJ3HsesW86KCwsUBjlDHHzyBl4jKEsZy7/WXPffClNX7VTv7vyF/GQiDEP54gQYOwgBmR+WJK1I++62Dw74hrz5hO3mOE39lQsfn5IP/WU9W5o/wI1emCp2v/dINX81wsm135k0kOIIJviKdR5mky2t3and5Q5wOPjAjAAeEFP+GDpj3r8vI0dfYEsnmO/Aycv26HHzmn/DmQ+xpE/bg8XGXQgGAxCOkDEOgaWkbeAUB/cONgOlaqw7RXGeeDq1o35sqH+L7p1nco/b4Z2ch4m1rnPb/iTobLycJZYIpAl+Y8BiUe3oxVnTiVPMsen4qmCTJ3nLHdCN96xbKuIlowZJ9T9uIiUp3t6zPZ8dPQHKCAqnT3tf8sQVIo+IEz6R64gzWcRf/+QZLGjLntdJ3M9vdJ+UbHQ6aEgZusdeWd0lnvOcu6TyW5D+NMBjGGfb1fNhnSB5yZ00Zwmgdums+dO/i8AAAD//0R/8kkAAAAGSURBVAMAowVAfTG6XeoAAAAASUVORK5CYII=")
)

# ---------------------------------------------------------------------------
# Language entry
# ---------------------------------------------------------------------------

$LangRelative = "src/main/resources/assets/droingos_decor/lang/en_us.json"
$LangPath = Join-Path $Root $LangRelative
Backup-File $LangRelative

if (Test-Path -LiteralPath $LangPath) {
    $Lang = Get-Content -LiteralPath $LangPath -Raw | ConvertFrom-Json
} else {
    $Lang = [pscustomobject]@{}
}

$Lang | Add-Member `
    -NotePropertyName "item.droingos_decor.buddy_bobblehead" `
    -NotePropertyValue "Buddy Bobblehead" `
    -Force

[System.IO.File]::WriteAllText(
        $LangPath,
        ($Lang | ConvertTo-Json -Depth 20),
        $Utf8NoBom
)

Write-Host ""
Write-Host "Added Buddy Bobblehead."
Write-Host "Backup directory: $BackupRoot"
Write-Host ""
Write-Host "Building..."
Write-Host ""

& .\gradlew.bat build

if ($LASTEXITCODE -ne 0) {
    throw "Build failed. Send the compile output. Backup: $BackupRoot"
}

Write-Host ""
Write-Host "Build successful."
Write-Host ""
Write-Host "Test:"
Write-Host "  1. Buddy appears under Bobbleheads."
Write-Host "  2. His head uses the same spring motion as the others."
Write-Host "  3. Right-click bobbles his head and plays a high-pitched wolf sound."
