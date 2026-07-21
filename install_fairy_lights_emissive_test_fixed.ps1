param(
    [string]$ProjectRoot = "C:\Users\mmcdo\Desktop\Droingos-Decor"
)

$ErrorActionPreference = "Stop"
Write-Host "Starting fairy-light installer..."
Set-Location $ProjectRoot
Write-Host "Project: $ProjectRoot"

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $full = Join-Path $ProjectRoot $Path
    $dir = Split-Path -Parent $full
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    [System.IO.File]::WriteAllText(
        $full,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Replace-Required {
    param(
        [string]$Path,
        [string]$Old,
        [string]$New
    )
    $full = Join-Path $ProjectRoot $Path
    $text = [System.IO.File]::ReadAllText($full)
    if (-not $text.Contains($Old)) {
        throw "Could not find expected source text in $Path. No changes were made to that file."
    }
    $text = $text.Replace($Old, $New)
    [System.IO.File]::WriteAllText(
        $full,
        $text,
        [System.Text.UTF8Encoding]::new($false)
    )
}

$backup = Join-Path $ProjectRoot ("fairy_lights_test_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Force -Path $backup | Out-Null

$backupFiles = @(
    "src\main\java\net\droingo\decor\registry\DecorBlocks.java",
    "src\main\java\net\droingo\decor\registry\DecorItems.java",
    "src\main\java\net\droingo\decor\registry\DecorBlockEntities.java",
    "src\main\java\net\droingo\decor\registry\DecorDefinitionRegistry.java",
    "src\main\java\net\droingo\decor\client\DroingosDecorClient.java",
    "src\main\resources\assets\droingos_decor\lang\en_us.json"
)

foreach ($relative in $backupFiles) {
    $source = Join-Path $ProjectRoot $relative
    if (Test-Path $source) {
        $destination = Join-Path $backup $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
        Copy-Item $source $destination -Force
    }
}


Write-Utf8NoBom -Path "src/main/java/net/droingo/decor/content/FairyLightsTestBlock.java" -Content @'
package net.droingo.decor.content;

import com.mojang.serialization.MapCodec;
import net.droingo.decor.registry.DecorBlockEntities;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.block.BaseEntityBlock;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;
import net.minecraft.world.level.BlockGetter;
import org.jetbrains.annotations.Nullable;

public final class FairyLightsTestBlock extends BaseEntityBlock {
    public static final MapCodec<FairyLightsTestBlock> CODEC =
            simpleCodec(FairyLightsTestBlock::new);

    private static final VoxelShape SHAPE = Shapes.box(
            0.45D, 0.35D, 0.0D,
            0.55D, 0.55D, 1.0D
    );

    public FairyLightsTestBlock(Properties properties) {
        super(properties);
    }

    @Override
    protected MapCodec<? extends BaseEntityBlock> codec() {
        return CODEC;
    }

    @Override
    public RenderShape getRenderShape(BlockState state) {
        return RenderShape.INVISIBLE;
    }

    @Nullable
    @Override
    public BlockEntity newBlockEntity(BlockPos pos, BlockState state) {
        return new FairyLightsTestBlockEntity(pos, state);
    }

    @Override
    protected VoxelShape getShape(
            BlockState state,
            BlockGetter level,
            BlockPos pos,
            CollisionContext context
    ) {
        return SHAPE;
    }

    @Override
    protected VoxelShape getCollisionShape(
            BlockState state,
            BlockGetter level,
            BlockPos pos,
            CollisionContext context
    ) {
        return Shapes.empty();
    }
}
'@

Write-Utf8NoBom -Path "src/main/java/net/droingo/decor/content/FairyLightsTestBlockEntity.java" -Content @'
package net.droingo.decor.content;

import net.droingo.decor.registry.DecorBlockEntities;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;

public final class FairyLightsTestBlockEntity extends BlockEntity {
    public FairyLightsTestBlockEntity(BlockPos pos, BlockState state) {
        super(DecorBlockEntities.FAIRY_LIGHTS_TEST.get(), pos, state);
    }
}
'@

Write-Utf8NoBom -Path "src/main/java/net/droingo/decor/client/render/FairyLightsTestRenderer.java" -Content @'
package net.droingo.decor.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import net.droingo.decor.DroingosDecor;
import net.droingo.decor.content.FairyLightsTestBlockEntity;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.block.BlockRenderDispatcher;
import net.minecraft.client.renderer.blockentity.BlockEntityRenderer;
import net.minecraft.client.renderer.blockentity.BlockEntityRendererProvider;
import net.minecraft.client.resources.model.BakedModel;
import net.minecraft.client.resources.model.ModelResourceLocation;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.block.Blocks;
import net.neoforged.neoforge.client.model.data.ModelData;

public final class FairyLightsTestRenderer
        implements BlockEntityRenderer<FairyLightsTestBlockEntity> {

    private static final ResourceLocation NORMAL_MODEL =
            id("block/fairy_lights_test_normal");

    private static final ResourceLocation GLOW_MODEL =
            id("block/fairy_lights_test_glow");

    private static final ResourceLocation EMISSIVE_TEXTURE =
            id("textures/block/fairy_lights_emissive.png");

    private static final int FULL_BRIGHT = 0x00F000F0;

    private final BlockRenderDispatcher blockRenderer;

    public FairyLightsTestRenderer(
            BlockEntityRendererProvider.Context context
    ) {
        this.blockRenderer = context.getBlockRenderDispatcher();
    }

    @Override
    public void render(
            FairyLightsTestBlockEntity blockEntity,
            float partialTick,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int packedLight,
            int packedOverlay
    ) {
        renderModel(
                NORMAL_MODEL,
                RenderType.cutout(),
                poseStack,
                buffers,
                packedLight,
                packedOverlay
        );

        renderModel(
                GLOW_MODEL,
                RenderType.entityTranslucentEmissive(EMISSIVE_TEXTURE),
                poseStack,
                buffers,
                FULL_BRIGHT,
                packedOverlay
        );
    }

    private void renderModel(
            ResourceLocation location,
            RenderType renderType,
            PoseStack poseStack,
            MultiBufferSource buffers,
            int light,
            int overlay
    ) {
        BakedModel model = Minecraft.getInstance()
                .getModelManager()
                .getModel(ModelResourceLocation.standalone(location));

        VertexConsumer consumer = buffers.getBuffer(renderType);

        blockRenderer.getModelRenderer().renderModel(
                poseStack.last(),
                consumer,
                Blocks.AIR.defaultBlockState(),
                model,
                1.0F,
                1.0F,
                1.0F,
                light,
                overlay,
                ModelData.EMPTY,
                renderType
        );
    }

    @Override
    public boolean shouldRenderOffScreen(
            FairyLightsTestBlockEntity blockEntity
    ) {
        return true;
    }

    private static ResourceLocation id(String path) {
        return ResourceLocation.fromNamespaceAndPath(
                DroingosDecor.MOD_ID,
                path
        );
    }
}
'@

Write-Utf8NoBom -Path "src/main/resources/assets/droingos_decor/models/block/fairy_lights_test_normal.json" -Content @'
{
  "parent": "minecraft:block/block",
  "texture_size": [
    32,
    32
  ],
  "textures": {
    "0": "droingos_decor:block/fairy_lights",
    "particle": "droingos_decor:block/fairy_lights"
  },
  "elements": [
    {
      "from": [
        7.75,
        7,
        0
      ],
      "to": [
        8.25,
        7.5,
        16
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          8,
          7.25,
          15
        ]
      },
      "faces": {
        "north": {
          "uv": [
            2.5,
            1,
            2.75,
            1.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            0,
            0,
            8,
            0.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            1.5,
            2.5,
            1.75,
            2.75
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            0,
            0.5,
            8,
            0.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0.25,
            9,
            0,
            1
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            0.75,
            1,
            0.5,
            9
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        8,
        6.6,
        7.9
      ],
      "to": [
        8,
        7,
        8.2
      ],
      "rotation": {
        "angle": 45,
        "axis": "y",
        "origin": [
          8,
          7,
          8.05
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            0.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            2.5,
            1.5,
            2.75,
            1.75
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            0.25
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            2,
            2.5,
            2.25,
            2.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0,
            0.25,
            0,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            0,
            0,
            0,
            0.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        8,
        6.6,
        7.9
      ],
      "to": [
        8,
        7,
        8.2
      ],
      "rotation": {
        "angle": -45,
        "axis": "y",
        "origin": [
          8,
          7,
          8.05
        ]
      },
      "faces": {
        "north": {
          "uv": [
            0,
            0,
            0,
            0.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            2.5,
            2,
            2.75,
            2.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            0,
            0,
            0,
            0.25
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            2.5,
            2.5,
            2.75,
            2.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            0,
            0.25,
            0,
            0
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            0,
            0,
            0,
            0.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        7.75,
        6.1,
        7.8
      ],
      "to": [
        8.25,
        6.6,
        8.3
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          8,
          7,
          8.05
        ]
      },
      "faces": {
        "north": {
          "uv": [
            1,
            3,
            1.25,
            3.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            3,
            1,
            3.25,
            1.25
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            1.5,
            3,
            1.75,
            3.25
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            3,
            1.5,
            3.25,
            1.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            2.25,
            3.25,
            2,
            3
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            3.25,
            2,
            3,
            2.25
          ],
          "texture": "#0"
        }
      }
    },
    {
      "from": [
        7.5,
        6,
        15
      ],
      "to": [
        8.5,
        8,
        16
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          8,
          7.3,
          15
        ]
      },
      "faces": {
        "north": {
          "uv": [
            1,
            1,
            1.5,
            2
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            1.5,
            1,
            2,
            2
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            1,
            2,
            1.5,
            3
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            2,
            1,
            2.5,
            2
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            2,
            2.5,
            1.5,
            2
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            2.5,
            2,
            2,
            2.5
          ],
          "texture": "#0"
        }
      }
    }
  ]
}
'@

Write-Utf8NoBom -Path "src/main/resources/assets/droingos_decor/models/block/fairy_lights_test_glow.json" -Content @'
{
  "parent": "minecraft:block/block",
  "texture_size": [
    32,
    32
  ],
  "textures": {
    "0": "droingos_decor:block/fairy_lights_emissive",
    "particle": "droingos_decor:block/fairy_lights"
  },
  "elements": [
    {
      "from": [
        7.65,
        6,
        7.7
      ],
      "to": [
        8.35,
        6.7,
        8.4
      ],
      "rotation": {
        "angle": 0,
        "axis": "y",
        "origin": [
          8,
          7,
          8.05
        ]
      },
      "faces": {
        "north": {
          "uv": [
            2.5,
            3,
            2.75,
            3.25
          ],
          "texture": "#0"
        },
        "east": {
          "uv": [
            3,
            2.5,
            3.25,
            2.75
          ],
          "texture": "#0"
        },
        "south": {
          "uv": [
            3,
            3,
            3.25,
            3.25
          ],
          "texture": "#0"
        },
        "west": {
          "uv": [
            1,
            3.5,
            1.25,
            3.75
          ],
          "texture": "#0"
        },
        "up": {
          "uv": [
            3.75,
            1.25,
            3.5,
            1
          ],
          "texture": "#0"
        },
        "down": {
          "uv": [
            1.75,
            3.5,
            1.5,
            3.75
          ],
          "texture": "#0"
        }
      }
    }
  ]
}
'@

Write-Utf8NoBom -Path "src/main/resources/assets/droingos_decor/models/item/fairy_lights.json" -Content @'
{
  "parent": "droingos_decor:block/fairy_lights_test_normal"
}
'@

Write-Utf8NoBom -Path "src/main/resources/assets/droingos_decor/blockstates/fairy_lights_test.json" -Content @'
{
  "variants": {
    "": {
      "model": "minecraft:block/air"
    }
  }
}
'@

Write-Utf8NoBom -Path "src/main/resources/data/droingos_decor/loot_table/blocks/fairy_lights_test.json" -Content @'
{
  "type": "minecraft:block",
  "pools": [
    {
      "bonus_rolls": 0.0,
      "conditions": [
        {
          "condition": "minecraft:survives_explosion"
        }
      ],
      "entries": [
        {
          "type": "minecraft:item",
          "name": "droingos_decor:fairy_lights"
        }
      ],
      "rolls": 1.0
    }
  ],
  "random_sequence": "droingos_decor:blocks/fairy_lights_test"
}
'@

$normalTexturePath = Join-Path $ProjectRoot "src\main\resources\assets\droingos_decor\textures\block\fairy_lights.png"
$emissiveTexturePath = Join-Path $ProjectRoot "src\main\resources\assets\droingos_decor\textures\block\fairy_lights_emissive.png"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $normalTexturePath) | Out-Null
[System.IO.File]::WriteAllBytes($normalTexturePath, [Convert]::FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAFgElEQVR4AeyaS29bRRTH70zshlR5o1SoASGxYMcCCan9BH0r7zbvJi2PsoMtSEgIJNgCK8qjJM27zVt9fwIqIbFEYoFUVXRRqYmUl5PYyeDfcY7jGKrK1Neprx3pP2fmzNyZ+z/nzBl7HHuuocGBphMnXPPJk0n0nj3rPuzvF/R3dLiGY8fchc5OgY5rb2x0gLHgg/PnHXi3u9uBi11dDrScOuWYHzAedLe2uq6WFuft85+9Nj9vwOydO2bm9u0khq5fN98PDAgGxsfN/L175pexMYGOm5ibM4Cx4IerVw34eWTEgCujowZM37plmB8wHoxMTZnR6Wmzz/w9e6mvz+EhvIxn8RLeAY3Hj4sHqeMtPPdeT494jqhpO3PGvd/b6/ra22WOnrY219nc7DqamqTNc+h4ljVaT592RAp6ngf7boDLg4MGD+FlPIuX8A6Yu3tXPEgdb+G5n4aHxXNEzeSNG+bHoSEzODEhcwxPTpqxmRkzPjsrbZ5Dx7OsMXXzpiFS0PM82HcDqBdUftZ7xH3Rf9R90n3Eaf3jznccnudll548kn3rnPuIdr7DphMIlxgvlKKNRIWvh+cZW/nyYdm3xphvaec77Pb2tnCIe1Qk5Jc3nBfZ3pJ2WVj4euQKFI///ithERoBgC0tLRUaFRUVIiGvpFFgkDJb4pEraB+qfyNhERoBgC0rKxMaxiR4QRgFpJGxeIAQDZojFh8/DFYEbG5uwjOJp+UAzdg1h15LWCr5RH5X7MrKyh4GJD3wx5Ma78uh++ZBpN77Zuw3w9nOwHiuCET2hwuw8T+kt7S0JJJwp8LnASRnOJKzHWkCkv3hAlIOPJqe9/l3s+J5zfaPHvwpe149rzIxOv9LW1tbKyyqq6sTsu5V2eOa7Q+//qa01fMqZXAAChv3qNBYXFwUGW/LHlcpygAXNhKJCL2qqiqR6mGVogxQkU7lXzkgfUDQ23Z9fV04rq6uiiy0wobDYeEcCoVEFlphS0pKhHPBGkC/DK2trYkhCq1IJsHy8vJC4y587fLyslQ2NjZEFlpha2pqCo3zHr42FouJQiNBGlksLjS/5S6de9txr6h3jOn3jfShA19dPCrjeQZk8VX+cyqbi+RXGz4giz/troHLl4XoZvIuUsdvRhPOkYd9KpJJUI9DP9bhig2S3DZx5aZfudGzHuSRgH7V0/YbNhqN+rrGgfDuB6x0chgEw/AC6vVUY6D3G/H7kGQQ+LYWN0wQgzB1FlqOJW6d2RaQp486fYwJW+ulGg+9H7D6CVCvx/1YBPLMq6Ed2dry8DwXruhBal3H5yQH+H3+Kwm8DNHQTsApSdpap59x4bj3Q8bkJgL0c0BlZSXr+4Kyne8b6mVtE+ohm1iS8KcOKkp280ai9/+Xz3oy+cvQswY+b79mfogylxqBuoIkqfWYk6tIbfom7cLCgm+Tp0+Mx1VHDtCcgO7h8u59hG4J3T70+wVbV1cnc/v1SVAm3ykghhEgv6Py1uOfdeoPJn6eo1+3yerG3h9sdHy2ZXILGGOyPbfMp0dZKumK0t21olt7Q137ql4qzU0S5F9ZeFP+OQLpFzQHpHpZ1yIqXjl4UJrUOQlo5GQLsFAuwNmvxFiP/Q9ZJEZBp0Cndb/lziHk3zJ4EfJkfY44jIBkRYhjBOoKTgntV52f0ncDkAMgrzmAPc5xl04SY6hx6MdoPOsneeb23QCXr/1u+HX565H7hl+bP73yq6GOpI86ElBHj6QNeEk/4bsB/Hz5bMxdNEA2rJjPcxQjIJ+9l413L0ZANqz4Is2R6bsUIyBTiwVtfDECgubRTPkUIyBTiwVtfDECgubRTPkUIyBTiwVtfDECgubRTPkUIyBTiwVtfDEC8t2jz/v+/wAAAP//H8fWTgAAAAZJREFUAwDTYqSfYwuVbwAAAABJRU5ErkJggg=="))
[System.IO.File]::WriteAllBytes($emissiveTexturePath, [Convert]::FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAABKUlEQVR4AeyUMQrCQBREowcQRUwRFcHC+5/HQhA1RUQUL6CwkOZv8RnS7M6fdMv+hJ03Lztvgj8CEFyARgagBnxf/Q99p+R52IDFupuVHAg9GwxgeFxiG9Buj7ENeA+32Aas2n1sA9BLpvR5+BIsPRB6vgzA53lP//h42/fXc1qjH65lPgOw3OzSPz7e9t3hlNa1BELPmQFAP1D7fDgAtjABsESirWVAtMZtXhlgiURby4Bojdu8MsASibaWAdEat3llgCUSbS0D2Bv38skAjxD7vgxgb9jLJwM8Quz7MoC9YS+fDPAIse/LAPaGvXwywCPEvi8D2BpG88gAlBjbvAxgaxTNIwNQYmzzMoCtUTSPDECJsc3LALZG0TwyACXGNi8Dam906vn/AAAA//+lFqEIAAAABklEQVQDAJ39GIFc8Jl7AAAAAElFTkSuQmCC"))

Replace-Required `
    -Path "src\main\java\net\droingo\decor\registry\DecorBlocks.java" `
    -Old "import net.droingo.decor.content.WallDecorBlock;" `
    -New "import net.droingo.decor.content.WallDecorBlock;`r`nimport net.droingo.decor.content.FairyLightsTestBlock;"

$oldText1 = @'
    public static final DeferredBlock<DecorContainerBlock> DECOR_CONTAINER =
'@
$newText1 = @'
    public static final DeferredBlock<FairyLightsTestBlock> FAIRY_LIGHTS_TEST =
            BLOCKS.registerBlock(
                    "fairy_lights_test",
                    FairyLightsTestBlock::new,
                    BlockBehaviour.Properties.of()
                            .mapColor(MapColor.NONE)
                            .strength(0.2F)
                            .sound(SoundType.WOOD)
                            .noOcclusion()
                            .noCollission()
            );

    public static final DeferredBlock<DecorContainerBlock> DECOR_CONTAINER =
'@
Replace-Required -Path "src\main\java\net\droingo\decor\registry\DecorBlocks.java" -Old $oldText1 -New $newText1

Replace-Required `
    -Path "src\main\java\net\droingo\decor\registry\DecorItems.java" `
    -Old "import net.minecraft.world.item.Item;" `
    -New "import net.minecraft.world.item.Item;`r`nimport net.minecraft.world.item.BlockItem;"

$oldText2 = @'
    public static final DeferredItem<Item> THE_BEAST_SKULL =
'@
$newText2 = @'
    public static final DeferredItem<BlockItem> FAIRY_LIGHTS =
            ITEMS.register(
                    "fairy_lights",
                    () -> new BlockItem(
                            DecorBlocks.FAIRY_LIGHTS_TEST.get(),
                            new Item.Properties()
                    )
            );

    public static final DeferredItem<Item> THE_BEAST_SKULL =
'@
Replace-Required -Path "src\main\java\net\droingo\decor\registry\DecorItems.java" -Old $oldText2 -New $newText2

Replace-Required `
    -Path "src\main\java\net\droingo\decor\registry\DecorBlockEntities.java" `
    -Old "import net.droingo.decor.content.WallDecorBlockEntity;" `
    -New "import net.droingo.decor.content.WallDecorBlockEntity;`r`nimport net.droingo.decor.content.FairyLightsTestBlockEntity;"

$oldText3 = @'
    public static final DeferredHolder<
            BlockEntityType<?>,
            BlockEntityType<DecorContainerBlockEntity>
            > DECOR_CONTAINER = TYPES.register(
'@
$newText3 = @'
    public static final DeferredHolder<
            BlockEntityType<?>,
            BlockEntityType<FairyLightsTestBlockEntity>
            > FAIRY_LIGHTS_TEST = TYPES.register(
            "fairy_lights_test",
            () -> BlockEntityType.Builder.of(
                    FairyLightsTestBlockEntity::new,
                    DecorBlocks.FAIRY_LIGHTS_TEST.get()
            ).build(null)
    );

    public static final DeferredHolder<
            BlockEntityType<?>,
            BlockEntityType<DecorContainerBlockEntity>
            > DECOR_CONTAINER = TYPES.register(
'@
Replace-Required -Path "src\main\java\net\droingo\decor\registry\DecorBlockEntities.java" -Old $oldText3 -New $newText3

Replace-Required `
    -Path "src\main\java\net\droingo\decor\client\DroingosDecorClient.java" `
    -Old "import net.droingo.decor.client.render.WallDecorRenderer;" `
    -New "import net.droingo.decor.client.render.WallDecorRenderer;`r`nimport net.droingo.decor.client.render.FairyLightsTestRenderer;"

$oldText4 = @'
        event.registerBlockEntityRenderer(
                DecorBlockEntities.DECOR_CONTAINER.get(),
                DecorContainerRenderer::new
        );
'@
$newText4 = @'
        event.registerBlockEntityRenderer(
                DecorBlockEntities.FAIRY_LIGHTS_TEST.get(),
                FairyLightsTestRenderer::new
        );

        event.registerBlockEntityRenderer(
                DecorBlockEntities.DECOR_CONTAINER.get(),
                DecorContainerRenderer::new
        );
'@
Replace-Required -Path "src\main\java\net\droingo\decor\client\DroingosDecorClient.java" -Old $oldText4 -New $newText4

$oldText5 = @'
        for (String modelName : java.util.List.of(
                "the_beast_floor_static",
'@
$newText5 = @'
        for (String modelName : java.util.List.of(
                "fairy_lights_test_normal",
                "fairy_lights_test_glow",
                "the_beast_floor_static",
'@
Replace-Required -Path "src\main\java\net\droingo\decor\client\DroingosDecorClient.java" -Old $oldText5 -New $newText5

$oldText6 = @'
        ResourceLocation beastSkullId = id("the_beast_skull");
'@
$newText6 = @'
        ResourceLocation fairyLightsId = id("fairy_lights");
        register(
                DecorDefinition.builder(fairyLightsId)
                        .category(DecorCategory.LIGHTING)
                        .placement(DecorPlacementType.SMALL)
                        .item(DecorItems.FAIRY_LIGHTS::get)
                        .build()
        );

        ResourceLocation beastSkullId = id("the_beast_skull");
'@
Replace-Required -Path "src\main\java\net\droingo\decor\registry\DecorDefinitionRegistry.java" -Old $oldText6 -New $newText6

$langPath = Join-Path $ProjectRoot "src\main\resources\assets\droingos_decor\lang\en_us.json"
$lang = Get-Content $langPath -Raw | ConvertFrom-Json
$lang | Add-Member -NotePropertyName "item.droingos_decor.fairy_lights" -NotePropertyValue "Fairy Lights" -Force
$lang | Add-Member -NotePropertyName "block.droingos_decor.fairy_lights_test" -NotePropertyValue "Fairy Lights Test Strand" -Force
$langJson = $lang | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText(
    $langPath,
    $langJson,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host ""
Write-Host "Fairy-light emissive test strand installed."
Write-Host "Backup: $backup"
Write-Host ""
Write-Host "Compiling..."
& .\gradlew.bat compileJava
if ($LASTEXITCODE -ne 0) {
    throw "Compilation failed. Restore the backup above before retrying."
}

Write-Host ""
Write-Host "Build passed."
Write-Host "Launch the client, find Fairy Lights in the Lighting section, and place it in a dark room."
Write-Host "This first pass is deliberately a static one-block strand to test the model and Iris/Sodium-safe emissive pass."
