param(
  [Parameter(Mandatory)]
  [pscustomobject]$Context
)

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot ".." "lib" "Common.psm1") -Force

function Get-UidZeroAccounts {
  if (-not (Test-Path "/etc/passwd")) {
    return @()
  }
  $accounts = @()
  foreach ($line in Get-Content "/etc/passwd" -ErrorAction SilentlyContinue) {
    $parts = $line -split ":"
    if ($parts.Count -ge 3 -and [int]$parts[2] -eq 0) {
      $accounts += $parts[0]
    }
  }
  return $accounts
}

function Get-LockedAccounts {
  if (-not (Test-Path "/etc/shadow")) {
    return $null
  }
  $locked = @()
  try {
    foreach ($line in Get-Content "/etc/shadow") {
      $parts = $line -split ":"
      if ($parts.Count -ge 2 -and ($parts[1].StartsWith("!") -or $parts[1].StartsWith("*"))) {
        $locked += $parts[0]
      }
    }
  }
  catch {
    return $null
  }
  return $locked
}

function Scan-SudoFile {
  param(
    [Parameter(Mandatory)]
    [string]$Path
  )

  if (-not (Test-Path $Path)) {
    return
  }

  try {
    $lines = Get-Content $Path -ErrorAction Stop
  }
  catch {
    Write-Warn -Context $Context -Message "$Path not readable; cannot assess sudo rules."
    return
  }

  $hits = $lines | Where-Object { $_ -match "^[^#].*NOPASSWD" }
  if ($hits) {
    Write-Warn -Context $Context -Message "NOPASSWD entries in ${Path}:"
    foreach ($line in $hits) {
      Write-Info "  $line"
      if ($line -match "ALL\s*=\s*\(ALL\).*NOPASSWD:\s*ALL") {
        Write-Crit -Context $Context -Message "Very broad NOPASSWD rule detected in $Path (ALL=(ALL) NOPASSWD: ALL)."
      }
    }
  }
}

Write-Section "Users & sudo"

$passwdPath = "/etc/passwd"
if (-not (Test-Path $passwdPath)) {
  Write-Info "No $passwdPath found; skipping Unix-specific sudo/users checks on this host."
  return
}

$uidZero = @(Get-UidZeroAccounts)
if ($uidZero.Count -gt 0) {
  Write-Info "UID 0 accounts: $($uidZero -join ' ')"
  if ($uidZero | Where-Object { $_ -ne "root" }) {
    Write-Crit -Context $Context -Message "Non-root account(s) with UID 0 detected – high risk."
  }
}
else {
  Write-Info "UID 0 accounts: (none)"
}

$locked = Get-LockedAccounts
if ($null -eq $locked) {
  Write-Warn -Context $Context -Message "/etc/shadow not readable; password state checks incomplete."
}
else {
  $lockedList = @($locked)
  if ($lockedList.Count -gt 0) {
    Write-Info "Locked/disabled accounts (shadow): $($lockedList -join ' ')"
  }
  else {
    Write-Info "Locked/disabled accounts (shadow): (none)"
  }
}

Scan-SudoFile -Path "/etc/sudoers"

$sudoersD = "/etc/sudoers.d"
if (Test-Path $sudoersD) {
  Get-ChildItem -Path $sudoersD -File -ErrorAction SilentlyContinue | ForEach-Object {
    Scan-SudoFile -Path $_.FullName
  }
}
