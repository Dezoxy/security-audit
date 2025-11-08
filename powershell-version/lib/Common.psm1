Set-StrictMode -Version Latest

$script:LogFile = $null

function Initialize-Logger {
  param(
    [Parameter(Mandatory)]
    [string]$LogFile
  )

  $script:LogFile = $LogFile
  $logDir = Split-Path -Parent $LogFile
  if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
  }
  New-Item -ItemType File -Path $LogFile -Force | Out-Null
}

function Write-LogLine {
  param(
    [Parameter(Mandatory)]
    [string]$Message,
    [ValidateSet("Gray","Cyan","Yellow","Red","Green","White","DarkGray")]
    [string]$Color = "Gray"
  )

  if ($PSBoundParameters.ContainsKey("Color") -and $Color) {
    Write-Host $Message -ForegroundColor $Color
  }
  else {
    Write-Host $Message
  }

  if ($script:LogFile) {
    Add-Content -Path $script:LogFile -Value $Message
  }
}

function Write-Raw {
  param(
    [string]$Message = ""
  )
  Write-LogLine -Message $Message -Color "Gray"
}

function Get-Timestamp {
  (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
}

function Write-Banner {
  param(
    [Parameter(Mandatory)]
    [string]$Title,
    [Parameter(Mandatory)]
    [string]$BaseDir,
    [Parameter(Mandatory)]
    [string]$LogFile
  )

  Write-Raw ("=" * 50)
  Write-Raw $Title
  Write-Raw "Base dir: $BaseDir"
  Write-Raw "Log file: $LogFile"
  Write-Raw ("=" * 50)
  Write-Raw ""
  Write-Raw "Starting run at: $(Get-Timestamp)"
  Write-Raw ""
}

function Write-Separator {
  param(
    [Parameter(Mandatory)]
    [string]$Label
  )

  Write-Raw ""
  Write-Raw "▶ Running check: $Label"
  Write-Raw ("-" * 50)
}

function New-CheckContext {
  param(
    [Parameter(Mandatory)]
    [string]$Label
  )

  [pscustomobject]@{
    Label     = $Label
    WarnCount = 0
    CritCount = 0
  }
}

function Write-Section {
  param(
    [Parameter(Mandatory)]
    [string]$Title
  )

  Write-Raw "== $Title =="
}

function Write-Info {
  param(
    [string]$Message
  )

  Write-LogLine -Message "[INFO] $Message" -Color "Cyan"
}

function Write-Warn {
  param(
    [Parameter(Mandatory)]
    [string]$Message,
    [pscustomobject]$Context
  )

  if ($PSBoundParameters.ContainsKey("Context") -and $null -ne $Context) {
    $Context.WarnCount++
  }
  Write-LogLine -Message "[WARN] $Message" -Color "Yellow"
}

function Write-Crit {
  param(
    [Parameter(Mandatory)]
    [string]$Message,
    [pscustomobject]$Context
  )

  if ($PSBoundParameters.ContainsKey("Context") -and $null -ne $Context) {
    $Context.CritCount++
  }
  Write-LogLine -Message "[CRIT] $Message" -Color "Red"
}

function Write-CheckSummary {
  param(
    [Parameter(Mandatory)]
    [pscustomobject]$Context
  )

  Write-Raw "Summary ($($Context.Label)): WARN=$($Context.WarnCount), CRIT=$($Context.CritCount)"
}

function Write-OverallSummary {
  param(
    [Parameter(Mandatory)]
    [int]$WarnTotal,
    [Parameter(Mandatory)]
    [int]$CritTotal
  )

  Write-Raw ""
  Write-Raw ("=" * 50)
  Write-Raw "Overall summary:"
  Write-Raw "  Checks with WARN : $WarnTotal"
  Write-Raw "  Checks with CRIT : $CritTotal"
  Write-Raw "  Finished at: $(Get-Timestamp)"
  Write-Raw ("=" * 50)
}

function Test-CommandAvailable {
  param(
    [Parameter(Mandatory)]
    [string]$Name
  )

  return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

Export-ModuleMember -Function *
