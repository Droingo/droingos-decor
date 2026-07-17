$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$ProjectRoot = (Get-Location).Path
$RelativePath = "src/main/java/net/droingo/decor/registry/DecorDefinitionRegistry.java"
$FilePath = Join-Path $ProjectRoot $RelativePath
$BackupRoot = Join-Path $ProjectRoot (".overlay_registry_repair_" + (Get-Date -Format "yyyyMMdd_HHmmss"))

if (!(Test-Path -LiteralPath $FilePath)) {
    throw "Could not find: $FilePath"
}

$BackupPath = Join-Path $BackupRoot $RelativePath
$BackupDirectory = Split-Path -Parent $BackupPath
New-Item -ItemType Directory -Force -Path $BackupDirectory | Out-Null
Copy-Item -LiteralPath $FilePath -Destination $BackupPath -Force

$Text = [System.IO.File]::ReadAllText($FilePath)

# Remove any currently misplaced overlay definitions, wherever the failed patch
# inserted them.
$OverlayPattern = '(?s)\s*ResourceLocation\s+mossyBottomId\s*=\s*id\("mossy_bottom"\);.*?ResourceLocation\s+wetBottomId\s*=\s*id\("wet_bottom"\);.*?\.build\(\)\s*\);\s*'

$Text = [regex]::Replace(
    $Text,
    $OverlayPattern,
    "`r`n",
    1
)

$OverlayBlock = @'

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

# Find the register(...) method that follows bootstrap().
$RegisterMarker = "public static DecorDefinition register"
$RegisterIndex = $Text.IndexOf($RegisterMarker)

if ($RegisterIndex -lt 0) {
    throw "Could not find the public register(...) method."
}

# Walk backward from the register method to the immediately preceding closing
# brace. That brace is the end of bootstrap(), regardless of formatting.
$BootstrapCloseIndex = $Text.LastIndexOf("}", $RegisterIndex)

if ($BootstrapCloseIndex -lt 0) {
    throw "Could not find the closing brace before register(...)."
}

$Before = $Text.Substring(0, $BootstrapCloseIndex)
$After = $Text.Substring($BootstrapCloseIndex)

$Text = $Before.TrimEnd() + $OverlayBlock + "`r`n    " + $After.TrimStart()

[System.IO.File]::WriteAllText(
    $FilePath,
    $Text,
    $Utf8NoBom
)

Write-Host "Repaired DecorDefinitionRegistry.java"
Write-Host "Backup: $BackupPath"
Write-Host ""
Write-Host "Building..."
Write-Host ""

& .\gradlew.bat build

if ($LASTEXITCODE -ne 0) {
    throw "Build still failed. Send the new compile output. Backup: $BackupPath"
}

Write-Host ""
Write-Host "Build successful."
