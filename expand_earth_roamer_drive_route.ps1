$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Root = (Get-Location).Path
$RelativePath = "src/main/java/net/droingo/decor/client/render/HalfDecorRenderer.java"
$Target = Join-Path $Root $RelativePath
$BackupRoot = Join-Path $Root (".earth_roamer_route_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
$Backup = Join-Path $BackupRoot $RelativePath

if (!(Test-Path -LiteralPath (Join-Path $Root "build.gradle"))) {
    throw "Run this script from the Droingo's Decor project root."
}

if (!(Test-Path -LiteralPath $Target)) {
    throw "Missing file: $Target"
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Backup) | Out-Null
Copy-Item -LiteralPath $Target -Destination $Backup -Force

$Text = [System.IO.File]::ReadAllText($Target)

$OldRadius = '    private static final double DRIVE_RADIUS = 2.25D / 16.0D;'
$NewRadius = '    private static final double DRIVE_RADIUS = 0.85D;'

if (!$Text.Contains($OldRadius)) {
    throw "Could not find the current DRIVE_RADIUS value."
}

$Text = $Text.Replace($OldRadius, $NewRadius)

# Keep the whole loop visible even while the visual model leaves its source block.
$ClassAnchor = @'
public final class HalfDecorRenderer
        implements BlockEntityRenderer<HalfDecorBlockEntity> {
'@

$ClassReplacement = @'
public final class HalfDecorRenderer
        implements BlockEntityRenderer<HalfDecorBlockEntity> {

    @Override
    public boolean shouldRenderOffScreen(
            HalfDecorBlockEntity blockEntity
    ) {
        return true;
    }
'@

if (!$Text.Contains("shouldRenderOffScreen(")) {
    if (!$Text.Contains($ClassAnchor)) {
        throw "Could not find the HalfDecorRenderer class declaration."
    }

    $Text = $Text.Replace($ClassAnchor, $ClassReplacement)
}

[System.IO.File]::WriteAllText($Target, $Text, $Utf8NoBom)

Write-Host ""
Write-Host "Expanded the Earth Roamer route from a tiny in-block loop to a 0.85-block radius circle."
Write-Host "Also enabled off-screen rendering so the animated model is not culled while away from its source block."
Write-Host "Backup: $Backup"
Write-Host ""
Write-Host "Building..."
Write-Host ""

& .\gradlew.bat build

if ($LASTEXITCODE -ne 0) {
    throw "Build failed. Send the compile output. Backup: $Backup"
}

Write-Host ""
Write-Host "Build successful."
Write-Host "Right-click the Earth Roamer and confirm it now leaves the source block and drives a visible loop."
