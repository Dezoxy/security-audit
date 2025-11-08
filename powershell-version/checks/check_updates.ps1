param(
  [Parameter(Mandatory)]
  [pscustomobject]$Context
)

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot ".." "lib" "Common.psm1") -Force

function Invoke-CommandText {
  param(
    [Parameter(Mandatory)]
    [string]$Command,
    [string[]]$Arguments = @()
  )

  try {
    return (& $Command @Arguments 2>$null)
  }
  catch {
    throw $_
  }
}

Write-Section "Package updates"

if (Test-CommandAvailable -Name "apt-get") {
  Write-Info "Detected apt-based system."

  if (Test-CommandAvailable -Name "unattended-upgrades") {
    Write-Info "unattended-upgrades installed (automatic security updates available)."
  }

  if (Test-CommandAvailable -Name "apt") {
    Write-Info "Checking for upgradable packages (apt list --upgradable)..."
    try {
      $output = Invoke-CommandText -Command "apt" -Arguments @("list","--upgradable")
      $lines = $output | Select-Object -Skip 1 -First 20
      if ($lines) {
        Write-Warn -Context $Context -Message "Packages available for upgrade (showing first 20):"
        foreach ($line in $lines) {
          Write-Info "  $line"
        }
      }
      else {
        Write-Info "No upgradable packages found (or unable to list)."
      }
    }
    catch {
      Write-Warn -Context $Context -Message "Failed to list apt upgrades: $($_.Exception.Message)"
    }
  }
}
elseif (Test-CommandAvailable -Name "dnf") {
  Write-Info "Detected dnf-based system (RHEL/Rocky/Fedora)."
  Write-Info "Checking for security updates (dnf updateinfo list security)..."

  try {
    $output = Invoke-CommandText -Command "dnf" -Arguments @("updateinfo","list","security")
  }
  catch {
    Write-Warn -Context $Context -Message "Failed to query dnf updateinfo: $($_.Exception.Message)"
    return
  }

  $important = $false
  foreach ($line in ($output | Select-Object -First 20)) {
    if ($line -match "Important/" -or $line -match "Critical/") {
      $important = $true
    }
  }

  if ($important) {
    Write-Crit -Context $Context -Message "Important/Critical security updates are pending:"
  }
  elseif ($output) {
    Write-Warn -Context $Context -Message "Security updates are available (none flagged as Important/Critical in first lines)."
  }
  else {
    Write-Info "No security updates reported by dnf updateinfo."
  }

  foreach ($line in ($output | Select-Object -First 20)) {
    Write-Info "  $line"
  }
}
elseif (Test-CommandAvailable -Name "yum") {
  Write-Info "Detected yum-based system."
  Write-Warn -Context $Context -Message "Please review 'yum check-update' output manually for pending updates."
}
else {
  Write-Warn -Context $Context -Message "Unknown/no package manager detected; cannot assess updates."
}
