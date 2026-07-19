$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Root = (Get-Location).Path
$Path = Join-Path $Root "src/main/java/net/droingo/decor/entity/TinyDecorEntity.java"

if (-not (Test-Path -LiteralPath $Path)) {
    throw "Could not find TinyDecorEntity.java. Run this from the project root."
}

$Text = [System.IO.File]::ReadAllText($Path)

$Pattern = '(?s)\s*if \(!level\(\)\.isClientSide && tickCount % 20 == 0\) \{\s*BlockPos support = BlockPos\.containing\(\s*getX\(\),\s*getY\(\) - 0\.0625D,\s*getZ\(\)\s*\);\s*if \(!level\(\)\.getBlockState\(support\)\.isFaceSturdy\(\s*level\(\),\s*support,\s*net\.minecraft\.core\.Direction\.UP,\s*SupportType\.CENTER\s*\)\) \{\s*dropAndDiscard\(null\);\s*\}\s*\}\s*'

$Updated = [regex]::Replace(
    $Text,
    $Pattern,
    "`r`n"
)

if ($Updated -eq $Text) {
    throw "Could not find the old support-check block in TinyDecorEntity.java."
}

$Updated = $Updated.Replace(
    "import net.minecraft.world.level.block.SupportType;`r`n",
    ""
)
$Updated = $Updated.Replace(
    "import net.minecraft.world.level.block.SupportType;`n",
    ""
)

[System.IO.File]::WriteAllText(
    $Path,
    $Updated,
    $Utf8NoBom
)

Write-Host ""
Write-Host "Removed the world-space support check that caused tiny decor to pop off moving sublevels."
Write-Host "Building..."
Write-Host ""

& ".\gradlew.bat" build

if ($LASTEXITCODE -ne 0) {
    throw "Build failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Build successful."
