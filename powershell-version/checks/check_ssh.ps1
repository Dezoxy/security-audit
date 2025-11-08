param(
  [Parameter(Mandatory)]
  [pscustomobject]$Context
)

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot ".." "lib" "Common.psm1") -Force

function Get-SshConfigValue {
  param(
    [Parameter(Mandatory)]
    [string]$Path,
    [Parameter(Mandatory)]
    [string]$Key
  )

  if (-not (Test-Path $Path)) {
    return $null
  }

  $value = $null
  foreach ($line in Get-Content -Path $Path -ErrorAction SilentlyContinue) {
    $trim = $line.Trim()
    if (-not $trim -or $trim.StartsWith("#")) { continue }
    $parts = $trim -split "\s+", 3
    if ($parts[0].ToLower() -eq $Key.ToLower() -and $parts.Length -ge 2) {
      $value = $parts[1].ToLower()
    }
  }
  return $value
}

Write-Section "SSH configuration"

if ($IsWindows) {
  $service = Get-Service -Name "sshd" -ErrorAction SilentlyContinue
  if ($service) {
    Write-Info "sshd service status: $($service.Status)"
    if ($service.Status -ne "Running") {
      Write-Warn -Context $Context -Message "OpenSSH service installed but not running."
    }
  }
  else {
    Write-Info "OpenSSH server service not installed."
  }

  $winConfigCandidates = @(
    "$env:ProgramData\ssh\sshd_config",
    "C:\Windows\System32\OpenSSH\sshd_config",
    "$env:ProgramFiles\OpenSSH\etc\sshd_config"
  )
  $configPath = $winConfigCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

  if (-not $configPath) {
    Write-Info "No Windows sshd_config found; skipping SSH config checks."
    return
  }

  Write-Info "Evaluating $configPath"
}
else {
  $configPath = "/etc/ssh/sshd_config"
  if (-not (Test-Path $configPath)) {
    Write-Info "No $configPath found (sshd may not be running on this host)."
    return
  }
  Write-Info "Evaluating $configPath"
}

$permitRoot = Get-SshConfigValue -Path $configPath -Key "PermitRootLogin"
$passwordAuth = Get-SshConfigValue -Path $configPath -Key "PasswordAuthentication"
$emptyPasswords = Get-SshConfigValue -Path $configPath -Key "PermitEmptyPasswords"
$protocol = Get-SshConfigValue -Path $configPath -Key "Protocol"

if ($permitRoot -eq "yes") {
  Write-Crit -Context $Context -Message "PermitRootLogin is YES – root over SSH is high risk."
}
elseif ($permitRoot) {
  Write-Info "PermitRootLogin=$permitRoot"
}
else {
  Write-Warn -Context $Context -Message "PermitRootLogin not set – verify distribution default (often 'prohibit-password')."
}

if ($passwordAuth -eq "yes") {
  Write-Warn -Context $Context -Message "PasswordAuthentication=YES – consider key-only auth for servers."
}
elseif ($passwordAuth -eq "no") {
  Write-Info "PasswordAuthentication=NO (keys-only auth enforced)."
}
else {
  Write-Warn -Context $Context -Message "PasswordAuthentication not explicitly set – check defaults."
}

if ($emptyPasswords -eq "yes") {
  Write-Crit -Context $Context -Message "PermitEmptyPasswords=YES – extremely dangerous."
}

if ($protocol -and $protocol -ne "2") {
  Write-Crit -Context $Context -Message "SSH Protocol not restricted to 2."
}
