# Removes Service Catalog from the org: deploys current force-app (strips app nav), then deletes
# org-only Lightning tab + FlexiPage + LWC + Visualforce stack.
# Run from repo root:
#   .\scripts\deploy-remove-service-catalog-from-org.ps1
# Optional: -TargetOrg myAlias

param([string]$TargetOrg = "")

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

function Invoke-SfDeploy {
    param([string[]]$Args)
    Write-Host "Running: sf $($Args -join ' ')"
    & sf @Args
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

# 1) Push updated CustomApplication (removes both catalog tabs from nav) and rest of source
$deploySource = @("project", "deploy", "start", "--source-dir", "force-app/main/default", "--ignore-warnings")
if ($TargetOrg) { $deploySource += @("--target-org", $TargetOrg) }
Invoke-SfDeploy $deploySource

# 2) Delete metadata that only exists in org or must be removed explicitly (tabs, FlexiPage, LWC, VF, Apex, object)
$destructive = @(
    "project", "deploy", "start",
    "--manifest", "manifest/package-empty.xml",
    "--post-destructive-changes", "manifest/destructiveChanges-service-catalog.xml",
    "--ignore-warnings"
)
if ($TargetOrg) { $destructive += @("--target-org", $TargetOrg) }
Invoke-SfDeploy $destructive
