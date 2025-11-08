#!/usr/bin/env pwsh
[CmdletBinding()]
param(
  [switch]$ListChecks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ChecksDir = Join-Path $ScriptDir "checks"
$LogDir = if ($env:LOG_DIR) { $env:LOG_DIR } else { Join-Path $ScriptDir "logs" }

Import-Module (Join-Path $ScriptDir "lib/Common.psm1") -Force

if (-not (Test-Path $LogDir)) {
  New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile = Join-Path $LogDir "security_orchestrator_$timestamp.log"

Initialize-Logger -LogFile $LogFile

$latest = Join-Path $LogDir "latest.log"
if (Test-Path $latest) {
  Remove-Item -Path $latest -Force
}
try {
  New-Item -ItemType SymbolicLink -Path $latest -Target (Split-Path -Leaf $LogFile) -Force | Out-Null
}
catch {
  Set-Content -Path $latest -Value (Split-Path -Leaf $LogFile)
}

$Checks = @(
  @{ Label = "OS"; Script = "check_os.ps1" },
  @{ Label = "updates"; Script = "check_updates.ps1" },
  @{ Label = "filesystem"; Script = "check_filesystem.ps1" },
  @{ Label = "network/firewall"; Script = "check_network.ps1" },
  @{ Label = "logging/audit"; Script = "check_logging.ps1" },
  @{ Label = "SSH"; Script = "check_ssh.ps1" },
  @{ Label = "sudo/users"; Script = "check_sudo.ps1" },
  @{ Label = "Docker"; Script = "check_docker.ps1" },
  @{ Label = "Kubernetes"; Script = "check_k8s.ps1" }
)

if ($ListChecks) {
  $Checks | ForEach-Object { Write-Output "$($_.Label): $($_.Script)" }
  exit 0
}

Write-Banner -Title "DevSecOps Security Orchestrator" -BaseDir $ScriptDir -LogFile $LogFile

$TotalWarn = 0
$TotalCrit = 0

foreach ($check in $Checks) {
  $context = New-CheckContext -Label $check.Label
  Write-Separator -Label "$($check.Label) ($($check.Script))"

  $scriptPath = Join-Path $ChecksDir $check.Script
  if (-not (Test-Path $scriptPath)) {
    Write-Warn -Context $context -Message "Script $scriptPath missing."
    continue
  }

  try {
    & $scriptPath -Context $context
  }
  catch {
    Write-Warn -Context $context -Message ("Check '{0}' failed: {1}" -f $check.Label, $_.Exception.Message)
    if ($env:DEBUG -eq "1") {
      Write-Info $_.Exception | Out-String
    }
  }

  Write-CheckSummary -Context $context
  $TotalWarn += $context.WarnCount
  $TotalCrit += $context.CritCount
}

Write-OverallSummary -WarnTotal $TotalWarn -CritTotal $TotalCrit

if ($TotalCrit -gt 0) { exit 2 }
elseif ($TotalWarn -gt 0) { exit 1 }
else { exit 0 }
