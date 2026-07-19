$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Root = (Get-Location).Path

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $FullPath = Join-Path $Root $Path
    $Directory = Split-Path -Parent $FullPath

    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    }

    [System.IO.File]::WriteAllText($FullPath, $Content, $Utf8NoBom)
}

Write-Utf8NoBom "src/main/java/net/droingo/decor/registry/DecorEntities.java" @'
package net.droingo.decor.registry;

import net.droingo.decor.DroingosDecor;
import net.droingo.decor.entity.BeastSkullSeatEntity;
import net.minecraft.core.registries.Registries;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.MobCategory;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforge.registries.DeferredHolder;
import net.neoforged.neoforge.registries.DeferredRegister;

public final class DecorEntities {
    public static final DeferredRegister<EntityType<?>> ENTITY_TYPES =
            DeferredRegister.create(Registries.ENTITY_TYPE, DroingosDecor.MOD_ID);

    public static final DeferredHolder<EntityType<?>, EntityType<BeastSkullSeatEntity>> BEAST_SKULL_SEAT =
            ENTITY_TYPES.register(
                    "beast_skull_seat",
                    () -> EntityType.Builder
                            .<BeastSkullSeatEntity>of(
                                    BeastSkullSeatEntity::new,
                                    MobCategory.MISC
                            )
                            .sized(0.1F, 0.1F)
                            .clientTrackingRange(8)
                            .updateInterval(1)
                            .build("beast_skull_seat")
            );

    private DecorEntities() {
    }

    public static void register(IEventBus bus) {
        ENTITY_TYPES.register(bus);
    }
}
'@

$BlockPath = Join-Path $Root "src/main/java/net/droingo/decor/content/BeastSkullBlock.java"

if (-not (Test-Path -LiteralPath $BlockPath)) {
    throw "Could not find BeastSkullBlock.java. Run this from the Droingo's Decor project root."
}

$BlockText = [System.IO.File]::ReadAllText($BlockPath)

$OldTicker = "protected <T extends BlockEntity> BlockEntityTicker<T> getTicker("
$NewTicker = "public <T extends BlockEntity> BlockEntityTicker<T> getTicker("

if ($BlockText.Contains($OldTicker)) {
    $BlockText = $BlockText.Replace($OldTicker, $NewTicker)
}

[System.IO.File]::WriteAllText($BlockPath, $BlockText, $Utf8NoBom)

Write-Host ""
Write-Host "Repaired the Beast Skull entity registry and block ticker visibility."
Write-Host "Building..."
Write-Host ""

& ".\gradlew.bat" build

if ($LASTEXITCODE -ne 0) {
    throw "Build failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Build successful."
