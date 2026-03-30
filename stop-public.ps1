$ErrorActionPreference = "Stop"

$runtimeRoot = Join-Path $PSScriptRoot ".runtime"
$serverPidFile = Join-Path $runtimeRoot "public-server.pid"
$tunnelPidFile = Join-Path $runtimeRoot "public-tunnel.pid"

function Stop-TrackedProcess {
  param([string]$PidFile)

  if (-not (Test-Path $PidFile)) {
    return
  }

  $pidValue = (Get-Content $PidFile -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
  if ([string]::IsNullOrWhiteSpace($pidValue)) {
    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    return
  }

  try {
    Stop-Process -Id ([int]$pidValue) -Force -ErrorAction Stop
  }
  catch {
  }

  Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
}

Stop-TrackedProcess -PidFile $tunnelPidFile
Stop-TrackedProcess -PidFile $serverPidFile

Write-Output "Public site processes stopped."
