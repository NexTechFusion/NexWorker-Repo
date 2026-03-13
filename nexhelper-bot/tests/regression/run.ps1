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
  $container = docker compose ps --format json | ConvertFrom-Json | Where-Object { $_.Service -eq "nexhelper" } | Select-Object -First 1
  if (-not $container) {
    throw "No running nexhelper service found. Start it with ./start.sh first."
  }

  function Run-InContainer {
    param([string]$Command)
    $result = docker compose exec -T nexhelper bash -lc $Command
    return $result
  }

  $base = "/app/skills"

  $docStore = Run-InContainer "$base/document-handler/nexhelper-doc store --type rechnung --amount 120.50 --supplier 'Mueller GmbH' --number RE-PS1 --date 2026-03-12 --entity default --source-text 'Rechnung fuer default' --idempotency-key evt_ps1_1"
  $docJson = $docStore | ConvertFrom-Json
  if (-not $docJson.document.id) { throw "Document store failed" }

  $dupe = Run-InContainer "$base/document-handler/nexhelper-doc store --type rechnung --amount 120.50 --supplier 'Mueller GmbH' --number RE-PS1 --date 2026-03-12 --entity default --source-text 'Rechnung fuer default'"
  $dupeJson = $dupe | ConvertFrom-Json
  if ($dupeJson.status -ne "duplicate") { throw "Duplicate detection failed" }

  $search = Run-InContainer "$base/document-handler/nexhelper-doc search --query Mueller --limit 5"
  $searchJson = $search | ConvertFrom-Json
  if ($searchJson.Count -lt 1) { throw "Search failed" }

  $rem = Run-InContainer "$base/reminder-system/nexhelper-reminder create --user ps1 --text test --datetime 2000-01-01T00:00:00Z --idempotency-key rem_ps1_1"
  $remJson = $rem | ConvertFrom-Json
  if (-not $remJson.reminder.id) { throw "Reminder creation failed" }

  $due = Run-InContainer "$base/reminder-system/nexhelper-reminder due"
  $dueJson = $due | ConvertFrom-Json
  if ($dueJson.Count -lt 1) { throw "Due reminder processing failed" }

  $health = Run-InContainer "$base/common/nexhelper-healthcheck"
  $healthJson = $health | ConvertFrom-Json
  if (-not $healthJson.status) { throw "Healthcheck failed" }

  @{
    status = "pass"
    checks = @(
      "document_store",
      "duplicate_detection",
      "search",
      "reminder_create",
      "reminder_due",
      "healthcheck"
    )
  } | ConvertTo-Json -Depth 4
}
finally {
  Pop-Location
}
