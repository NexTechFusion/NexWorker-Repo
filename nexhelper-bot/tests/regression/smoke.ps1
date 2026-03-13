param(
  [Parameter(Mandatory = $true)]
  [string]$CustomerDir
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $CustomerDir)) {
  throw "Customer directory not found: $CustomerDir"
}

Push-Location $CustomerDir
try {
  $output = docker compose exec -T nexhelper nexhelper-smoke
  $json = $output | ConvertFrom-Json
  if ($json.fail -gt 0) {
    throw "Smoke checks failed: $($json.fail)"
  }
  $output
}
finally {
  Pop-Location
}
