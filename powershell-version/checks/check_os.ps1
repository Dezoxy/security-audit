param(
  [Parameter(Mandatory)]
  [pscustomobject]$Context
)

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot ".." "lib" "Common.psm1") -Force

function Get-OsPrettyName {
  $osRelease = "/etc/os-release"
  if (Test-Path $osRelease) {
    $data = Get-Content -Path $osRelease -ErrorAction SilentlyContinue
    foreach ($line in $data) {
      if ($line -match "^PRETTY_NAME=") {
        return ($line -replace "^PRETTY_NAME=", "").Trim('"')
      }
    }
    foreach ($line in $data) {
      if ($line -match "^NAME=") {
        return ($line -replace "^NAME=", "").Trim('"')
      }
    }
  }
  return (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Caption)
}

function Get-KernelVersion {
  if (Test-CommandAvailable -Name "uname") {
    try {
      return (& uname -r).Trim()
    }
    catch {}
  }
  return [System.Environment]::OSVersion.VersionString
}

Write-Section "Host & OS"
$hostname = [System.Net.Dns]::GetHostName()
$kernel = Get-KernelVersion
$osName = Get-OsPrettyName

Write-Info "Hostname: $hostname"
Write-Info "OS:       $osName"
Write-Info "Kernel:   $kernel"

if (Test-Path "/var/run/reboot-required") {
  Write-Warn -Context $Context -Message "System indicates a reboot is required (/var/run/reboot-required)."
}
