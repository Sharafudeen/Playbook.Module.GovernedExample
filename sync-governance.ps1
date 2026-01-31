<#
.SYNOPSIS
  Synchronises Oqtane AI governance files into a solution without removing anything.

.DESCRIPTION
  - Adds missing governance file references to .slnx
  - Ensures required governance files physically exist
  - Never deletes solution content
  - Supports DryRun and Verbose output

.PARAMETER DryRun
  Shows what would change without modifying files.

.PARAMETER Help
  Displays this help text.

.EXAMPLE
  ./sync-governance.ps1

.EXAMPLE
  ./sync-governance.ps1 -DryRun -Verbose
#>

[CmdletBinding()]
param (
    [switch] $DryRun,
    [switch] $Help
)

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    return
}

$ErrorActionPreference = "Stop"
$Changes = @()

Write-Verbose "Starting governance sync"

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

$Root = Get-Location
$PlaybookRoot = Resolve-Path "$Root\..\oqtane-ai-playbook\module-playbook-example"

$slnx = Get-ChildItem -Path $Root -Filter *.slnx | Select-Object -First 1
if (-not $slnx) {
    throw "No .slnx file found in solution root."
}

Write-Verbose "Solution file: $($slnx.Name)"

# ------------------------------------------------------------
# Load solution XML
# ------------------------------------------------------------

[xml]$xml = Get-Content $slnx.FullName
$solutionNode = $xml.Solution

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

function Get-OrCreateFolderNode {
    param (
        [string] $Name
    )

    $node = $solutionNode.Folder | Where-Object { $_.Name -eq $Name }
    if ($node) { return $node }

    Write-Verbose "Creating solution folder: $Name"
    if (-not $DryRun) {
        $node = $xml.CreateElement("Folder")
        $node.SetAttribute("Name", $Name)
        $solutionNode.AppendChild($node) | Out-Null
    }

    $script:Changes += "Add folder: $Name"
    return $node
}

function Ensure-FileReference {
    param (
        [System.Xml.XmlElement] $FolderNode,
        [string] $Path
    )

    if ($FolderNode.File | Where-Object { $_.Path -eq $Path }) {
        return
    }

    Write-Verbose "Adding file reference: $Path"

    if (-not $DryRun) {
        $fileNode = $xml.CreateElement("File")
        $fileNode.SetAttribute("Path", $Path)
        $FolderNode.AppendChild($fileNode) | Out-Null
    }

    $script:Changes += "Reference file: $Path"
}

function Ensure-PhysicalFile {
    param (
        [string] $RelativePath
    )

    $source = Join-Path $PlaybookRoot $RelativePath
    $target = Join-Path $Root $RelativePath

    if (Test-Path $target) {
        Write-Verbose "File exists: $RelativePath"
        return
    }

    if (-not (Test-Path $source)) {
        Write-Warning "Playbook source missing: $RelativePath"
        return
    }

    Write-Verbose "Materialising governance file: $RelativePath"

    if (-not $DryRun) {
        New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
        Copy-Item $source $target -Force
    }

    $script:Changes += "Create file: $RelativePath"
}

# ------------------------------------------------------------
# Materialised governance files (MUST exist)
# ------------------------------------------------------------

$MaterialisedFiles = @(
    "docs/deviations.md"
)

foreach ($file in $MaterialisedFiles) {
    Ensure-PhysicalFile -RelativePath $file
}

# ------------------------------------------------------------
# Governance folders + files
# ------------------------------------------------------------

$GovernanceFolders = @{
    "/docs/governance/" = @(
        "docs/governance/027-rules-index.md",
        "docs/governance/027x-structure-and-boundaries.md",
        "docs/governance/027x-repositories.md",
        "docs/governance/027x-packaging-and-dependencies.md"
    )
}

foreach ($folder in $GovernanceFolders.Keys) {
    $folderNode = Get-OrCreateFolderNode -Name $folder

    foreach ($file in $GovernanceFolders[$folder]) {
        $refPath = "../oqtane-ai-playbook/module-playbook-example/$file"
        Ensure-FileReference -FolderNode $folderNode -Path $refPath
    }
}

# ------------------------------------------------------------
# Save solution
# ------------------------------------------------------------

if ($Changes.Count -eq 0) {
    Write-Host "✔ Solution already compliant. No changes required."
}
else {
    Write-Host ""
    Write-Host "=== GOVERNANCE SYNC $(if ($DryRun) { '(DRY RUN)' }) ==="
    $Changes | ForEach-Object { Write-Host "• $_" }

    if (-not $DryRun) {
        $xml.Save($slnx.FullName)
        Write-Verbose "Solution file updated."
    }
}

Write-Host ""
Write-Host "✔ Governance sync completed successfully."
