$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$ProjectRoot = (Get-Location).Path
$BackupRoot = Join-Path $ProjectRoot (".overlay_compile_repair_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))

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

function Read-ProjectFile {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $Target = Join-Path $ProjectRoot $RelativePath

    if (!(Test-Path -LiteralPath $Target)) {
        throw "Missing required file: $Target"
    }

    return [System.IO.File]::ReadAllText($Target)
}

function Write-ProjectFile {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Content
    )

    Backup-File $RelativePath

    $Target = Join-Path $ProjectRoot $RelativePath
    [System.IO.File]::WriteAllText($Target, $Content, $Utf8NoBom)
}

if (!(Test-Path -LiteralPath (Join-Path $ProjectRoot "build.gradle"))) {
    throw "Run this script from the Droingo's Decor project root."
}

$AffectedFiles = @(
    "src/main/java/net/droingo/decor/api/DecorCategory.java",
    "src/main/java/net/droingo/decor/api/DecorPlacementType.java",
    "src/main/java/net/droingo/decor/registry/DecorItems.java",
    "src/main/java/net/droingo/decor/registry/DecorDefinitionRegistry.java",
    "src/main/java/net/droingo/decor/client/creative/CreativeCategoryScreenEvents.java"
)

Write-Host "Replacing literal PowerShell newline text in Java files..."

foreach ($RelativePath in $AffectedFiles) {
    $Content = Read-ProjectFile $RelativePath
    $Content = $Content.Replace('`r`n', "`r`n")
    $Content = $Content.Replace('`n', "`n")
    Write-ProjectFile $RelativePath $Content
}

Write-Host "Repairing DecorCategory.java..."

$CategoryRelative = "src/main/java/net/droingo/decor/api/DecorCategory.java"
$Category = Read-ProjectFile $CategoryRelative

$Category = [regex]::Replace(
    $Category,
    'OVERLAYS\s*\(\s*100\s*\)',
    'OVERLAYS("overlays", 70)'
)

if ($Category -notmatch 'OVERLAYS\s*\(\s*"overlays"\s*,\s*\d+\s*\)') {
    throw "Could not repair the OVERLAYS enum entry in DecorCategory.java."
}

Write-ProjectFile $CategoryRelative $Category

Write-Host "Repairing DecorDefinitionRegistry.java placement..."

$DefinitionsRelative = "src/main/java/net/droingo/decor/registry/DecorDefinitionRegistry.java"
$Definitions = Read-ProjectFile $DefinitionsRelative

$OverlayBlockPattern = '(?s)\s*ResourceLocation\s+mossyBottomId\s*=\s*id\("mossy_bottom"\);.*?ResourceLocation\s+wetBottomId\s*=\s*id\("wet_bottom"\);.*?\.build\(\)\s*\);\s*'

$OverlayMatch = [regex]::Match(
    $Definitions,
    $OverlayBlockPattern
)

if (!$OverlayMatch.Success) {
    throw "Could not locate the generated overlay definition block."
}

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

# Remove the misplaced block first.
$Definitions = [regex]::Replace(
    $Definitions,
    $OverlayBlockPattern,
    "`r`n",
    1
)

# Insert it immediately before bootstrap() closes, identified by the register
# method that follows bootstrap in this registry.
$BootstrapEndPattern = '(?s)(public\s+static\s+void\s+bootstrap\s*\(\s*\)\s*\{.*?)(\r?\n\s{4}\}\r?\n\r?\n\s{4}public\s+static\s+DecorDefinition\s+register)'

if (![regex]::IsMatch($Definitions, $BootstrapEndPattern)) {
    throw "Could not locate the end of bootstrap() in DecorDefinitionRegistry.java."
}

$Definitions = [regex]::Replace(
    $Definitions,
    $BootstrapEndPattern,
    {
        param($Match)

        return $Match.Groups[1].Value `
            + $OverlayBlock `
            + $Match.Groups[2].Value
    },
    1
)

Write-ProjectFile $DefinitionsRelative $Definitions

Write-Host "Normalising the Overlays creative label..."

$ScreenRelative = "src/main/java/net/droingo/decor/client/creative/CreativeCategoryScreenEvents.java"
$Screen = Read-ProjectFile $ScreenRelative

# Remove accidental duplicate labels, then insert one before the return.
$Screen = [regex]::Replace(
    $Screen,
    '\s*labels\.put\(\s*"overlays"\s*,\s*Component\.literal\("Overlays"\)\s*\);\s*',
    "`r`n"
)

$ReturnMarker = '        return Map.copyOf(labels);'

if (!$Screen.Contains($ReturnMarker)) {
    throw "Could not locate createLabels() return in CreativeCategoryScreenEvents.java."
}

$Screen = $Screen.Replace(
    $ReturnMarker,
    '        labels.put("overlays", Component.literal("Overlays"));' `
        + "`r`n`r`n" `
        + $ReturnMarker
)

Write-ProjectFile $ScreenRelative $Screen

Write-Host "Checking the creative-header switch..."

$ItemsRelative = "src/main/java/net/droingo/decor/registry/DecorItems.java"
$Items = Read-ProjectFile $ItemsRelative

if ($Items -notmatch 'case\s+OVERLAYS\s*->\s*OVERLAYS_HEADER\s*;') {
    $Items = [regex]::Replace(
        $Items,
        '(case\s+OUTDOOR_DECOR\s*->\s*OUTDOOR_DECOR_HEADER\s*;)',
        '$1' + "`r`n            case OVERLAYS -> OVERLAYS_HEADER;"
    )
}

Write-ProjectFile $ItemsRelative $Items

Write-Host ""
Write-Host "Overlay source repair applied."
Write-Host "Backup directory: $BackupRoot"
Write-Host ""
Write-Host "Building..."
Write-Host ""

& .\gradlew.bat build

if ($LASTEXITCODE -ne 0) {
    throw "Build still failed. The Java syntax corruption is repaired; send the new compile output so the remaining API errors can be fixed. Backup: $BackupRoot"
}

Write-Host ""
Write-Host "Build successful."
