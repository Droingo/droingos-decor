$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Root = (Get-Location).Path
$RelativePath = "src/main/java/net/droingo/decor/client/animation/HangingGravityMotionState.java"
$Target = Join-Path $Root $RelativePath
$BackupRoot = Join-Path $Root (".sweater_inertia_direction_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
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

$Old = @'
        Vec3 effectiveGravity = worldGravity.add(
                filteredAcceleration.scale(
                        INERTIA_STRENGTH
                )
        );
'@

$New = @'
        Vec3 effectiveGravity = worldGravity.subtract(
                filteredAcceleration.scale(
                        INERTIA_STRENGTH
                )
        );
'@

if (!$Text.Contains($Old)) {
    throw "Could not find the current sweater inertia calculation."
}

$Text = $Text.Replace($Old, $New)
[System.IO.File]::WriteAllText($Target, $Text, $Utf8NoBom)

Write-Host ""
Write-Host "Flipped only the sweater velocity/inertia response."
Write-Host "Gravity orientation and corrected wall axes are unchanged."
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
Write-Host "Test acceleration and braking on all four wall faces."
