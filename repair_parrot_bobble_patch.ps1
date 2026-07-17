$ErrorActionPreference = "Stop"

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Root = (Get-Location).Path
$BackupRoot = Join-Path $Root (".parrot_bobble_repair_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))

function Backup-File {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $Target = Join-Path $Root $RelativePath
    if (!(Test-Path -LiteralPath $Target)) {
        throw "Missing file: $RelativePath"
    }

    $Backup = Join-Path $BackupRoot $RelativePath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Backup) | Out-Null
    Copy-Item -LiteralPath $Target -Destination $Backup -Force
}

function Save-File {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $Target = Join-Path $Root $RelativePath
    [System.IO.File]::WriteAllText($Target, $Content, $Utf8NoBom)
}

if (!(Test-Path -LiteralPath (Join-Path $Root "build.gradle"))) {
    throw "Run this script from the Droingo's Decor project root."
}

$RendererRelative = "src/main/java/net/droingo/decor/client/render/DecorContainerRenderer.java"
$MotionRelative = "src/main/java/net/droingo/decor/client/animation/BobbleheadMotionState.java"

# ---------------------------------------------------------------------------
# Repair renderer patch using the exact current source layout.
# ---------------------------------------------------------------------------

Backup-File $RendererRelative
$RendererPath = Join-Path $Root $RendererRelative
$Renderer = [System.IO.File]::ReadAllText($RendererPath)

if (!$Renderer.Contains("import net.droingo.decor.client.animation.BobbleheadInteractionPulses;")) {
    $ImportAnchor = "import net.droingo.decor.client.animation.BobbleheadMotionState;"

    if (!$Renderer.Contains($ImportAnchor)) {
        throw "Could not find BobbleheadMotionState import in renderer."
    }

    $Renderer = $Renderer.Replace(
        $ImportAnchor,
        "import net.droingo.decor.client.animation.BobbleheadInteractionPulses;`r`n$ImportAnchor"
    )
}

if (!$Renderer.Contains("BobbleheadInteractionPulses.consume(blockEntity, slot)")) {
    $OldBlock = @'
        BobbleheadMotionState motion = getMotionState(blockEntity, slot);
        updateMotion(blockEntity, motion, centreX, centreZ, yawDegrees, render.pivot().y, partialTick);
'@

    $NewBlock = @'
        BobbleheadMotionState motion = getMotionState(blockEntity, slot);

        if (BobbleheadInteractionPulses.consume(blockEntity, slot)) {
            motion.addInteractionImpulse();
        }

        updateMotion(
                blockEntity,
                motion,
                centreX,
                centreZ,
                yawDegrees,
                render.pivot().y,
                partialTick
        );
'@

    if (!$Renderer.Contains($OldBlock)) {
        throw "Could not find the exact motion update block in DecorContainerRenderer.java."
    }

    $Renderer = $Renderer.Replace($OldBlock, $NewBlock)
}

Save-File $RendererRelative $Renderer

# ---------------------------------------------------------------------------
# Add the spring impulse if the failed script did not reach this step.
# ---------------------------------------------------------------------------

Backup-File $MotionRelative
$MotionPath = Join-Path $Root $MotionRelative
$Motion = [System.IO.File]::ReadAllText($MotionPath)

if (!$Motion.Contains("private float interactionRollDirection")) {
    $FieldAnchor = @'
    private float pitchVelocity;
    private float rollVelocity;
'@

    $FieldReplacement = @'
    private float pitchVelocity;
    private float rollVelocity;

    private float interactionRollDirection = 1.0F;
'@

    if (!$Motion.Contains($FieldAnchor)) {
        throw "Could not find bobblehead spring velocity fields."
    }

    $Motion = $Motion.Replace($FieldAnchor, $FieldReplacement)
}

if (!$Motion.Contains("public void addInteractionImpulse()")) {
    $MethodAnchor = @'
    public float getPitchDegrees() {
        return pitchDegrees;
    }
'@

    $MethodReplacement = @'
    /**
     * Gives the head a short nod and a small alternating sideways wobble.
     * This feeds the existing spring rather than running a separate animation.
     */
    public void addInteractionImpulse() {
        pitchVelocity += 6.5F;
        rollVelocity += 2.25F * interactionRollDirection;

        interactionRollDirection =
                -interactionRollDirection;
    }

    public float getPitchDegrees() {
        return pitchDegrees;
    }
'@

    if (!$Motion.Contains($MethodAnchor)) {
        throw "Could not find getPitchDegrees() in BobbleheadMotionState.java."
    }

    $Motion = $Motion.Replace($MethodAnchor, $MethodReplacement)
}

Save-File $MotionRelative $Motion

Write-Host ""
Write-Host "Repaired the remaining renderer and bobblehead impulse changes."
Write-Host "The earlier script had already applied the overlay spacing and interaction trigger before it stopped."
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
Write-Host ""
Write-Host "Test:"
Write-Host "  1. Overlays header position."
Write-Host "  2. Right-click parrot sound plus brief head bobble."
