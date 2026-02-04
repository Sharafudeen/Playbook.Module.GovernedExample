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
# Paths - HARDCODED FOR THIS SPECIFIC INSTALLATION
# ------------------------------------------------------------

$Root = Get-Location

# HARDCODED ABSOLUTE PATH - THIS IS FIXED FOR YOUR ENVIRONMENT
# This path is specific to your machine and should not change
$PlaybookRoot = "D:\Oqtane Development\oqtane-ai-playbook\module-playbook-example"

Write-Verbose "Root: $Root"
Write-Verbose "PlaybookRoot: $PlaybookRoot (HARDCODED)"

# Verify the playbook root exists
if (-not (Test-Path $PlaybookRoot)) {
    Write-Error "Playbook directory not found at hardcoded path: $PlaybookRoot"
    Write-Host ""
    Write-Host "This script uses a HARDCODED path that is specific to this development environment." -ForegroundColor Yellow
    Write-Host "The playbook must be at: $PlaybookRoot" -ForegroundColor Red
    Write-Host ""
    Write-Host "To fix this:" -ForegroundColor Cyan
    Write-Host "1. Ensure the playbook exists at the above path" -ForegroundColor White
    Write-Host "2. OR edit this script and update the `$PlaybookRoot` variable" -ForegroundColor White
    Write-Host ""
    throw "Playbook directory missing at hardcoded location."
}

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

    # Check if file already referenced
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
        return $true
    }

    if (-not (Test-Path $source)) {
        Write-Warning "Playbook source missing: $RelativePath"
        return $false
    }

    Write-Verbose "Materialising governance file: $RelativePath"

    if (-not $DryRun) {
        $targetDir = Split-Path $target -Parent
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        Copy-Item $source $target -Force
    }

    $script:Changes += "Create file: $RelativePath"
    return $true
}

# ------------------------------------------------------------
# Materialised governance files (MUST exist in playbook)
# ------------------------------------------------------------

$MaterialisedFiles = @(
    "docs/deviations.md",
    "docs/ai-decision-timeline.md" 
)

$MaterialisedFilesCreated = @()

foreach ($file in $MaterialisedFiles) {
    $created = Ensure-PhysicalFile -RelativePath $file
    if ($created) {
        $MaterialisedFilesCreated += $file
    }
}

# ------------------------------------------------------------
# Governance folders + files (ONLY IF THEY EXIST IN PLAYBOOK)
# ------------------------------------------------------------

# Find ONLY files that actually exist in the playbook's governance folder
$GovernanceSourcePath = Join-Path $PlaybookRoot "docs\governance"

if (Test-Path $GovernanceSourcePath) {
    $GovernanceFiles = Get-ChildItem -Path $GovernanceSourcePath -File -Filter "*.md" -ErrorAction SilentlyContinue
    
    if ($GovernanceFiles.Count -gt 0) {
        Write-Verbose "Found $($GovernanceFiles.Count) governance files in playbook"
        
        # Create the governance folder in solution
        $folderNode = Get-OrCreateFolderNode -Name "/docs/governance/"
        
        foreach ($govFile in $GovernanceFiles) {
            # HARDCODED ABSOLUTE PATH reference to the playbook file
            $absolutePath = $govFile.FullName
            Ensure-FileReference -FolderNode $folderNode -Path $absolutePath
        }
    } else {
        Write-Verbose "No .md files found in playbook governance folder"
    }
} else {
    Write-Warning "Governance folder not found in playbook: $GovernanceSourcePath"
}

# ------------------------------------------------------------
# Add materialized files to solution folder (ONLY IF CREATED)
# ------------------------------------------------------------

# Create /docs/ folder for materialized files
$docsFolderNode = Get-OrCreateFolderNode -Name "/docs/"

foreach ($file in $MaterialisedFilesCreated) {
    # Reference the local copy (absolute path in the solution)
    $absolutePath = Join-Path $Root $file
    Ensure-FileReference -FolderNode $docsFolderNode -Path $absolutePath
}

# ------------------------------------------------------------
# Save solution
# ------------------------------------------------------------

if ($Changes.Count -eq 0) {
    Write-Host "Solution already compliant. No changes required."
}
else {
    Write-Host ""
    Write-Host "=== GOVERNANCE SYNC $(if ($DryRun) { '(DRY RUN)' }) ==="
    $Changes | ForEach-Object { Write-Host "* $_" }

    if (-not $DryRun) {
        $xml.Save($slnx.FullName)
        Write-Verbose "Solution file updated."
    }
}

Write-Host ""
Write-Host "Governance sync completed successfully."