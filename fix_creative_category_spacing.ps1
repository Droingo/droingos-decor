$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$ProjectRoot = (Get-Location).Path
$BackupRoot = Join-Path $ProjectRoot (".creative_spacer_fix_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))

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

if (!(Test-Path -LiteralPath (Join-Path $ProjectRoot "build.gradle"))) {
    throw "Run this script from the Droingo's Decor project root."
}

$DecorItemsRelative = "src/main/java/net/droingo/decor/registry/DecorItems.java"
$CreativeTabsRelative = "src/main/java/net/droingo/decor/registry/DecorCreativeTabs.java"
$ScreenEventsRelative = "src/main/java/net/droingo/decor/client/creative/CreativeCategoryScreenEvents.java"

$DecorItemsPath = Join-Path $ProjectRoot $DecorItemsRelative
$CreativeTabsPath = Join-Path $ProjectRoot $CreativeTabsRelative
$ScreenEventsPath = Join-Path $ProjectRoot $ScreenEventsRelative

foreach ($RequiredPath in @(
    $DecorItemsPath,
    $CreativeTabsPath,
    $ScreenEventsPath
)) {
    if (!(Test-Path -LiteralPath $RequiredPath)) {
        throw "Missing required file: $RequiredPath"
    }
}

Write-Host "Patching DecorItems.java..."

$DecorItems = [System.IO.File]::ReadAllText($DecorItemsPath)

if ($DecorItems -match 'public\s+static\s+final\s+DeferredItem<Item>\s+CREATIVE_SPACER\s*=') {
    $DecorItems = [regex]::Replace(
        $DecorItems,
        'public\s+static\s+final\s+DeferredItem<Item>\s+CREATIVE_SPACER\s*=\s*registerInternalItem\("creative_spacer"\);',
        @'
public static final List<DeferredItem<Item>> CREATIVE_SPACERS =
            registerSpacers();
'@
    )
}
elseif ($DecorItems -match 'public\s+static\s+final\s+List<DeferredItem<Item>>\s+CREATIVE_SPACERS') {
    Write-Host "Unique spacer list is already registered."
}
else {
    throw "Could not find the existing CREATIVE_SPACER registration in DecorItems.java."
}

if ($DecorItems -notmatch 'private\s+static\s+List<DeferredItem<Item>>\s+registerSpacers\(') {
    $RegisterSpacersMethod = @'

    private static List<DeferredItem<Item>> registerSpacers() {
        List<DeferredItem<Item>> spacers = new ArrayList<>(8);

        for (int index = 0; index < 8; index++) {
            spacers.add(registerInternalItem(
                    "creative_spacer_" + index
            ));
        }

        return List.copyOf(spacers);
    }

'@

    $InsertionMarker = '    private static List<DeferredItem<Item>> registerHeader('

    if (!$DecorItems.Contains($InsertionMarker)) {
        throw "Could not find registerHeader(...) in DecorItems.java."
    }

    $DecorItems = $DecorItems.Replace(
        $InsertionMarker,
        $RegisterSpacersMethod + $InsertionMarker
    )
}

Write-Utf8NoBom $DecorItemsRelative $DecorItems

Write-Host "Patching DecorCreativeTabs.java..."

$CreativeTabs = [System.IO.File]::ReadAllText($CreativeTabsPath)

$OldPaddingPattern = '(?s)for\s*\(\s*int\s+index\s*=\s*0;\s*index\s*<\s*padding;\s*index\+\+\s*\)\s*\{\s*output\.accept\(\s*DecorItems\.CREATIVE_SPACER\.get\(\)\.getDefaultInstance\(\)\s*\);\s*\}'

if ([regex]::IsMatch($CreativeTabs, $OldPaddingPattern)) {
    $CreativeTabs = [regex]::Replace(
        $CreativeTabs,
        $OldPaddingPattern,
        @'
for (int index = 0; index < padding; index++) {
            output.accept(
                    DecorItems.CREATIVE_SPACERS
                            .get(index)
                            .get()
                            .getDefaultInstance()
            );
        }
'@
    )
}
elseif ($CreativeTabs -match 'DecorItems\.CREATIVE_SPACERS') {
    Write-Host "Creative tab already uses unique spacers."
}
else {
    throw "Could not find the creative-tab padding loop."
}

Write-Utf8NoBom $CreativeTabsRelative $CreativeTabs

Write-Host "Patching CreativeCategoryScreenEvents.java..."

$ScreenEvents = [System.IO.File]::ReadAllText($ScreenEventsPath)

if ($ScreenEvents.Contains('path.equals("creative_spacer")')) {
    $ScreenEvents = $ScreenEvents.Replace(
        'path.equals("creative_spacer")',
        'path.startsWith("creative_spacer_")'
    )
}
elseif ($ScreenEvents.Contains('path.startsWith("creative_spacer_")')) {
    Write-Host "Marker detection already supports unique spacers."
}
else {
    throw "Could not find creative spacer detection in CreativeCategoryScreenEvents.java."
}

Write-Utf8NoBom $ScreenEventsRelative $ScreenEvents

Write-Host "Creating transparent spacer item models..."

$ModelDirectory = "src/main/resources/assets/droingos_decor/models/item"

$ModelContent = @'
{
  "parent": "minecraft:item/generated",
  "textures": {
    "layer0": "droingos_decor:item/creative_layout_marker"
  }
}
'@

for ($Index = 0; $Index -lt 8; $Index++) {
    Write-Utf8NoBom `
        "$ModelDirectory/creative_spacer_$Index.json" `
        $ModelContent
}

$OldSpacerModel = Join-Path $ProjectRoot "$ModelDirectory/creative_spacer.json"

if (Test-Path -LiteralPath $OldSpacerModel) {
    Backup-File "$ModelDirectory/creative_spacer.json"
    Remove-Item -LiteralPath $OldSpacerModel -Force
}

Write-Host ""
Write-Host "Unique creative spacer patch installed."
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
Write-Host "Wall Decor should now begin at the left edge of a fresh row."
