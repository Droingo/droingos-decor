$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Root = (Get-Location).Path
$BackupRoot = Join-Path $Root (".parrot_bobble_final_repair_" + (Get-Date -Format "yyyyMMdd_HHmmss"))

function Backup-File {
    param([Parameter(Mandatory = $true)][string]$Path)

    $Relative = $Path.Substring($Root.Length).TrimStart("\")
    $Backup = Join-Path $BackupRoot $Relative

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Backup) | Out-Null
    Copy-Item -LiteralPath $Path -Destination $Backup -Force
}

function Save-Text {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text
    )

    [System.IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
}

if (!(Test-Path -LiteralPath (Join-Path $Root "build.gradle"))) {
    throw "Run this script from the Droingo's Decor project root."
}

$RendererPath = Join-Path $Root "src\main\java\net\droingo\decor\client\render\DecorContainerRenderer.java"
$MotionPath = Join-Path $Root "src\main\java\net\droingo\decor\client\animation\BobbleheadMotionState.java"

foreach ($Path in @($RendererPath, $MotionPath)) {
    if (!(Test-Path -LiteralPath $Path)) {
        throw "Missing file: $Path"
    }
}

# ---------------------------------------------------------------------------
# DecorContainerRenderer
# ---------------------------------------------------------------------------

Backup-File $RendererPath
$Renderer = [System.IO.File]::ReadAllText($RendererPath)

if (!$Renderer.Contains("import net.droingo.decor.client.animation.BobbleheadInteractionPulses;")) {
    $ImportPattern = [regex]::Escape(
        "import net.droingo.decor.client.animation.BobbleheadMotionState;"
    )

    if (!([regex]::IsMatch($Renderer, $ImportPattern))) {
        throw "Could not find BobbleheadMotionState import."
    }

    $Renderer = [regex]::Replace(
        $Renderer,
        $ImportPattern,
        "import net.droingo.decor.client.animation.BobbleheadInteractionPulses;`r`n" +
        "import net.droingo.decor.client.animation.BobbleheadMotionState;",
        1
    )
}

if (!$Renderer.Contains("BobbleheadInteractionPulses.consume(blockEntity, slot)")) {
    $Pattern = '(?ms)([ \t]*BobbleheadMotionState\s+motion\s*=\s*getMotionState\(blockEntity,\s*slot\);\s*\r?\n)([ \t]*updateMotion\(\s*blockEntity,\s*motion,\s*centreX,\s*centreZ,\s*yawDegrees,\s*render\.pivot\(\)\.y,\s*partialTick\s*\);)'

    if (!([regex]::IsMatch($Renderer, $Pattern))) {
        throw "Could not locate the bobblehead motion/updateMotion pair in DecorContainerRenderer.java."
    }

    $Replacement = @'
$1
        if (BobbleheadInteractionPulses.consume(blockEntity, slot)) {
            motion.addInteractionImpulse();
        }

$2
'@

    $Renderer = [regex]::Replace(
        $Renderer,
        $Pattern,
        $Replacement,
        1
    )
}

Save-Text $RendererPath $Renderer

# ---------------------------------------------------------------------------
# BobbleheadMotionState
# ---------------------------------------------------------------------------

Backup-File $MotionPath
$Motion = [System.IO.File]::ReadAllText($MotionPath)

if (!$Motion.Contains("private float interactionRollDirection")) {
    $FieldPattern = '(?ms)([ \t]*private\s+float\s+pitchVelocity\s*;\s*\r?\n[ \t]*private\s+float\s+rollVelocity\s*;)'

    if (!([regex]::IsMatch($Motion, $FieldPattern))) {
        throw "Could not locate pitchVelocity and rollVelocity fields."
    }

    $Motion = [regex]::Replace(
        $Motion,
        $FieldPattern,
        '$1' + "`r`n`r`n    private float interactionRollDirection = 1.0F;",
        1
    )
}

if (!$Motion.Contains("public void addInteractionImpulse()")) {
    $GetterPattern = '(?ms)([ \t]*public\s+float\s+getPitchDegrees\s*\(\s*\)\s*\{)'

    if (!([regex]::IsMatch($Motion, $GetterPattern))) {
        throw "Could not locate getPitchDegrees()."
    }

    $ImpulseMethod = @'
    /**
     * Gives the head a short nod and a small alternating sideways wobble.
     */
    public void addInteractionImpulse() {
        pitchVelocity += 6.5F;
        rollVelocity += 2.25F * interactionRollDirection;
        interactionRollDirection = -interactionRollDirection;
    }

'@

    $Motion = [regex]::Replace(
        $Motion,
        $GetterPattern,
        $ImpulseMethod + '$1',
        1
    )
}

Save-Text $MotionPath $Motion

Write-Host ""
Write-Host "Completed the parrot bobble repair."
Write-Host "Backup directory: $BackupRoot"
Write-Host ""
Write-Host "Building..."
Write-Host ""

& .\gradlew.bat build

if ($LASTEXITCODE -ne 0) {
    throw "Build failed. Send the compile output. Backup: $BackupRoot"
}

Write-Host ""
Write-Host "Build successful."
Write-Host "The earlier overlay spacing changes remain in place."
