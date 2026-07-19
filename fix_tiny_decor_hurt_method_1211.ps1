$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Root = (Get-Location).Path
$Path = Join-Path $Root "src/main/java/net/droingo/decor/entity/TinyDecorEntity.java"

if (-not (Test-Path -LiteralPath $Path)) {
    throw "Could not find TinyDecorEntity.java. Run this from the project root."
}

$Text = [System.IO.File]::ReadAllText($Path)

$Old = @'
    @Override
    public boolean hurtServer(
            ServerLevel level,
            DamageSource source,
            float amount
    ) {
        Entity attacker = source.getEntity();

        if (attacker instanceof Player player) {
            dropAndDiscard(player);
            return true;
        }

        return false;
    }
'@

$New = @'
    @Override
    public boolean hurt(
            DamageSource source,
            float amount
    ) {
        if (level().isClientSide) {
            return true;
        }

        Entity attacker = source.getEntity();

        if (attacker instanceof Player player) {
            dropAndDiscard(player);
            return true;
        }

        return false;
    }
'@

if (-not $Text.Contains($Old)) {
    throw "Could not find the expected hurtServer method in TinyDecorEntity.java."
}

$Text = $Text.Replace($Old, $New)

# Remove the now-unused import.
$Text = $Text.Replace(
    "import net.minecraft.server.level.ServerLevel;`r`n",
    ""
)
$Text = $Text.Replace(
    "import net.minecraft.server.level.ServerLevel;`n",
    ""
)

[System.IO.File]::WriteAllText(
    $Path,
    $Text,
    $Utf8NoBom
)

Write-Host ""
Write-Host "Replaced the newer hurtServer override with the Minecraft 1.21.1 hurt method."
Write-Host "Building..."
Write-Host ""

& ".\gradlew.bat" build

if ($LASTEXITCODE -ne 0) {
    throw "Build failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Build successful."
