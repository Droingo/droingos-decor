$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Root = (Get-Location).Path
$RelativePath = "src/main/java/net/droingo/decor/client/render/WallDecorRenderer.java"
$Target = Join-Path $Root $RelativePath
$BackupRoot = Join-Path $Root (".wall_axis_fix_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
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

$OldRight = @'
        Vec3 decorRight =
                worldLocalX.scale(cos)
                        .add(
                                worldLocalZ.scale(sin)
                        )
                        .normalize();
'@

$NewRight = @'
        Vec3 decorRight =
                worldLocalX.scale(cos)
                        .add(
                                worldLocalZ.scale(-sin)
                        )
                        .normalize();
'@

$OldToward = @'
        Vec3 towardWall =
                worldLocalX.scale(-sin)
                        .add(
                                worldLocalZ.scale(cos)
                        )
                        .normalize();
'@

$NewToward = @'
        Vec3 towardWall =
                worldLocalX.scale(sin)
                        .add(
                                worldLocalZ.scale(cos)
                        )
                        .normalize();
'@

if (!$Text.Contains($OldRight)) {
    throw "Could not find the current decorRight calculation."
}

if (!$Text.Contains($OldToward)) {
    throw "Could not find the current towardWall calculation."
}

$Text = $Text.Replace($OldRight, $NewRight)
$Text = $Text.Replace($OldToward, $NewToward)

[System.IO.File]::WriteAllText($Target, $Text, $Utf8NoBom)

Write-Host ""
Write-Host "Fixed east/west wall-local axis signs."
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
Write-Host "Test sweaters on north, south, east and west faces."
