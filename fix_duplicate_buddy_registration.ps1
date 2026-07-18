$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Root = (Get-Location).Path
$RelativePath = "src/main/java/net/droingo/decor/registry/DecorItems.java"
$Target = Join-Path $Root $RelativePath
$BackupRoot = Join-Path $Root (".buddy_duplicate_fix_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
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

$Pattern = '(?ms)^[ \t]*public\s+static\s+final\s+DeferredItem<Item>\s+BUDDY_BOBBLEHEAD\s*=\s*ITEMS\.register\(\s*"buddy_bobblehead",\s*\(\)\s*->\s*new\s+TinyDecorItem\(\s*"buddy_bobblehead",\s*new\s+Item\.Properties\(\)\s*\)\s*\);\s*'

$Matches = [regex]::Matches($Text, $Pattern)

if ($Matches.Count -lt 2) {
    throw "Expected at least two BUDDY_BOBBLEHEAD registrations, but found $($Matches.Count)."
}

# Keep the first registration and remove every duplicate after it.
for ($Index = $Matches.Count - 1; $Index -ge 1; $Index--) {
    $Match = $Matches[$Index]
    $Text = $Text.Remove($Match.Index, $Match.Length)
}

[System.IO.File]::WriteAllText($Target, $Text, $Utf8NoBom)

Write-Host ""
Write-Host "Removed duplicate Buddy item registrations."
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
