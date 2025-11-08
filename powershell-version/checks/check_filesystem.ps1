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

Write-Section "Filesystem & permissions"

if ($IsWindows) {
  Write-Info "Windows host detected – reviewing ACLs for common shared directories."
  function Test-BroadAcl {
    param(
      [Parameter(Mandatory)]
      [string]$Path
    )

    try {
      $acl = Get-Acl -Path $Path -ErrorAction Stop
    }
    catch {
      Write-Warn -Context $Context -Message "Unable to read ACL for $Path: $($_.Exception.Message)"
      return $false
    }

    $riskyIdentities = @("Everyone","BUILTIN\Users","NT AUTHORITY\Authenticated Users")
    foreach ($entry in $acl.Access) {
      if ($riskyIdentities -contains $entry.IdentityReference.Value) {
        $rights = $entry.FileSystemRights.ToString()
        if ($rights -match "FullControl|Modify|Write") {
          return $true
        }
      }
    }
    return $false
  }

  $targets = @("C:\Temp", "$env:TEMP", "C:\Users\Public", "C:\ProgramData") |
    Where-Object { $_ } |
    Select-Object -Unique |
    Where-Object { Test-Path $_ }

  if (-not $targets) {
    Write-Info "No common public directories found to inspect."
    return
  }

  $flagged = @()
  foreach ($path in $targets) {
    if (Test-BroadAcl -Path $path) {
      $flagged += $path
    }
  }

  if ($flagged.Count -gt 0) {
    Write-Warn -Context $Context -Message "Directories with Everyone/Users having write+ permissions:"
    foreach ($path in $flagged) {
      Write-Info "  $path"
    }
  }
  else {
    Write-Info "No obvious Windows directories with overly broad ACLs in common locations."
  }
  return
}

if (-not (Test-CommandAvailable -Name "find")) {
  Write-Warn -Context $Context -Message "find not available; skipping filesystem checks."
  return
}

# World-writable directories
$targets = @("/tmp","/var/tmp","/home") | Where-Object { Test-Path $_ }
if ($targets) {
  Write-Info "Scanning for world-writable dirs without sticky bit under /tmp /var/tmp /home..."
  try {
    $args = @($targets + @("-xdev","-type","d","-perm","-0002","!","-perm","-1000"))
    $output = Invoke-CommandText -Command "find" -Arguments $args
    $lines = $output | Where-Object { $_ } | Select-Object -First 30
    if ($lines) {
      Write-Warn -Context $Context -Message "World-writable dirs without sticky bit (first 30):"
      foreach ($line in $lines) {
        Write-Info "  $line"
      }
    }
    else {
      Write-Info "No obvious world-writable dirs without sticky bit in target paths."
    }
  }
  catch {
    Write-Warn -Context $Context -Message "Failed to scan world-writable dirs: $($_.Exception.Message)"
  }
}
else {
  Write-Info "Target directories /tmp /var/tmp /home not present; skipping world-writable scan."
}

# SUID/SGID
$binTargets = @("/bin","/sbin","/usr/bin","/usr/sbin") | Where-Object { Test-Path $_ }
if ($binTargets) {
  Write-Info "Scanning for SUID/SGID binaries in standard paths..."
  try {
    $args = @($binTargets + @("-xdev","(","-perm","-4000","-o","-perm","-2000",")","-type","f"))
    $output = Invoke-CommandText -Command "find" -Arguments $args
    $binaries = $output | Where-Object { $_ }
    Write-Info "Found $($binaries.Count) SUID/SGID binaries in standard paths."
    $custom = $binaries | Where-Object { $_ -like "/usr/local*" -or $_ -like "/opt*" }
    if ($custom) {
      Write-Warn -Context $Context -Message "SUID/SGID binaries in /usr/local or /opt (review carefully):"
      foreach ($line in ($custom | Select-Object -First 30)) {
        Write-Info "  $line"
      }
    }
  }
  catch {
    Write-Warn -Context $Context -Message "Failed to scan SUID/SGID binaries: $($_.Exception.Message)"
  }
}
else {
  Write-Info "Standard binary directories missing; skipping SUID/SGID scan."
}
