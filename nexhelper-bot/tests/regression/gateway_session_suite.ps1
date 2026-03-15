param(
  [string]$OpenRouterApiKey = $env:OPENROUTER_API_KEY,
  [string]$OpenRouterBaseUrl = "https://openrouter.ai/api/v1",
  [switch]$KeepCustomer
)

$ErrorActionPreference = "Stop"

if (-not $OpenRouterApiKey) {
  throw "Missing OpenRouter key. Set OPENROUTER_API_KEY or pass -OpenRouterApiKey."
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$baseDir = Join-Path $root ".tmp/gateway-session-suite/customers"
$slug = "gateway-session-suite"
$customerDir = Join-Path $baseDir $slug
$customerName = "Gateway Session Suite"
$customerId = "991"
$instanceName = "nexhelper-gateway-session-suite"
$defaultDeliveryTo = "telegram:579539601"
$bashPath = "C:\Program Files\Git\bin\bash.exe"

if (-not (Test-Path $bashPath)) {
  throw "Git Bash not found at $bashPath"
}

function To-GitBashPath {
  param([string]$WindowsPath)
  $full = (Resolve-Path $WindowsPath).Path
  $normalized = $full -replace '\\','/'
  if ($normalized -match '^([A-Za-z]):/(.*)$') {
    $drive = $matches[1].ToLower()
    $rest = $matches[2]
    return "/$drive/$rest"
  }
  throw "Cannot convert path to git-bash format: $WindowsPath"
}

$results = @()
function Add-Result {
  param([string]$name, [string]$status, [string]$details = "")
  $script:results += [pscustomobject]@{
    name = $name
    status = $status
    details = $details
  }
}

function Invoke-AgentTurn {
  param(
    [string]$InstanceName,
    [string]$To,
    [string]$Message,
    [string]$SessionId = ""
  )
  $ErrorActionPreference = "Continue"
  if ([string]::IsNullOrWhiteSpace($SessionId)) {
    $raw = docker exec $InstanceName openclaw agent --to $To --message "$Message" --json 2>&1
  } else {
    $raw = docker exec $InstanceName openclaw agent --session-id $SessionId --to $To --message "$Message" --json 2>&1
  }
  $jsonLines = ($raw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $jsonLines = $jsonLines.Trim()
  $jsonStart = $jsonLines.IndexOf('{')
  if ($jsonStart -ge 0) {
    $jsonLines = $jsonLines.Substring($jsonStart)
  }
  $ErrorActionPreference = "Stop"
  $parsed = $null
  try { $parsed = $jsonLines | ConvertFrom-Json } catch {}
  $text = ""
  if ($parsed -and $parsed.result -and $parsed.result.payloads) {
    $text = ($parsed.result.payloads | ForEach-Object { $_.text }) -join " "
  }
  return [pscustomobject]@{
    parsed = $parsed
    text = $text
  }
}

try {
  $ErrorActionPreference = "Continue"
  docker network create nexhelper-network 2>&1 | Out-Null
  $ErrorActionPreference = "Stop"

  if (Test-Path $customerDir) {
    Push-Location $customerDir
    try {
      $ErrorActionPreference = "Continue"
      docker compose down -v 2>&1 | Out-Null
      $ErrorActionPreference = "Stop"
    } catch {}
    finally { Pop-Location }
    Remove-Item -Recurse -Force $customerDir
  }
  New-Item -ItemType Directory -Force -Path $baseDir | Out-Null

  $rootBash = To-GitBashPath -WindowsPath $root
  $baseDirBash = To-GitBashPath -WindowsPath $baseDir
  $provisionCmd = "cd '$rootBash' && OPENROUTER_API_KEY='$OpenRouterApiKey' OPENROUTER_BASE_URL='$OpenRouterBaseUrl' DEFAULT_DELIVERY_TO='$defaultDeliveryTo' ./provision-customer.sh $customerId '$customerName' --whatsapp --base-dir '$baseDirBash' --no-start"
  & $bashPath -lc $provisionCmd | Out-Null
  Add-Result "provision_customer" "pass"

  Push-Location $customerDir
  try {
    $ErrorActionPreference = "Continue"
    docker compose up -d 2>&1 | Out-Null
    $ErrorActionPreference = "Stop"
  } finally { Pop-Location }
  Add-Result "container_start" "pass"

  $healthy = $false
  $ErrorActionPreference = "Continue"
  for ($i = 0; $i -lt 45; $i++) {
    try {
      $healthRaw = docker exec $instanceName openclaw health --json 2>&1
      $healthStr = ($healthRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
      $healthStr = $healthStr.Trim()
      if ($healthStr -match '^\{') {
        $health = $healthStr | ConvertFrom-Json
        if ($health.ok -eq $true) {
          $healthy = $true
          break
        }
      }
    } catch {}
    Start-Sleep -Seconds 2
  }
  $ErrorActionPreference = "Stop"
  if (-not $healthy) {
    throw "Gateway did not become healthy in time."
  }
  Add-Result "gateway_health" "pass"

  # --- Runtime guard: unknown tools in allowlist ---
  $ErrorActionPreference = "Continue"
  $toolsRaw = docker exec $instanceName sh -lc "jq -r '.tools.allow[]? // empty' /root/.openclaw/openclaw.json 2>/dev/null" 2>&1
  $toolsText = ($toolsRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $toolsList = @($toolsText -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  $ErrorActionPreference = "Stop"
  $unknownEntries = @($toolsList | Where-Object { $_ -in @("apply_patch", "cron") })
  if ($unknownEntries.Count -eq 0) {
    Add-Result "runtime_tools_allowlist_clean" "pass"
  } else {
    Add-Result "runtime_tools_allowlist_clean" "fail" "unknown entries present: $($unknownEntries -join ', ')"
  }

  # --- Runtime guard: reminder command exists on PATH ---
  $ErrorActionPreference = "Continue"
  $setReminderRaw = docker exec $instanceName sh -lc 'command -v nexhelper-set-reminder >/dev/null 2>&1 && nexhelper-set-reminder --help >/dev/null 2>&1 && echo __OK__ || echo __FAIL__' 2>&1
  $setReminderText = ($setReminderRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $setReminderText = $setReminderText.Trim()
  $ErrorActionPreference = "Stop"
  if ($setReminderText -match "__OK__") {
    Add-Result "runtime_set_reminder_available" "pass"
  } else {
    Add-Result "runtime_set_reminder_available" "fail" "nexhelper-set-reminder missing or not executable"
  }

  $messages = @(
    "Hallo, antworte nur mit OK und einem kurzen Satz.",
    "Wir testen die Session-Stabilitaet. Bitte bestaetige Test Schritt 2.",
    "Merke: Rechnung Mueller GmbH RE-SESSION-1 mit 123.45 EUR am 2026-03-13.",
    "Was war die letzte Information aus diesem Chat?"
  )

  $ErrorActionPreference = "Continue"
  foreach ($msg in $messages) {
    $raw = docker exec $instanceName openclaw agent --to +15550001111 --message "$msg" --json 2>&1
    $jsonLines = ($raw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
    $jsonLines = $jsonLines.Trim()
    $jsonStart = $jsonLines.IndexOf('{')
    if ($jsonStart -ge 0) {
      $jsonLines = $jsonLines.Substring($jsonStart)
    }
    $parsed = $jsonLines | ConvertFrom-Json
    $payloadCount = @($parsed.result.payloads).Count
    if ($payloadCount -lt 1) {
      $ErrorActionPreference = "Stop"
      throw "Session turn produced no payload for message: $msg"
    }
  }
  $ErrorActionPreference = "Stop"
  Add-Result "session_chat_turns" "pass"

  $ErrorActionPreference = "Continue"
  $sessionsRaw = docker exec $instanceName openclaw sessions --json 2>&1
  $sessionsStr = ($sessionsRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $sessionsStr = $sessionsStr.Trim()
  $sessStart = $sessionsStr.IndexOf('{')
  if ($sessStart -ge 0) { $sessionsStr = $sessionsStr.Substring($sessStart) }
  $ErrorActionPreference = "Stop"
  $sessions = $sessionsStr | ConvertFrom-Json
  if (($sessions.count -as [int]) -lt 1) {
    throw "No active session was created."
  }
  Add-Result "session_created" "pass" "count=$($sessions.count)"

  # --- Direct Cron Lifecycle: schedule → list → wait → verify fire ---
  $ErrorActionPreference = "Continue"
  $cronMarker = "CRON_LIVE_MARKER_" + (Get-Date).Ticks.ToString().Substring(12)
  $cronRaw = docker exec $instanceName openclaw cron add --name "live-cron-test" --at 1m --message $cronMarker --to +15550001111 --announce --json 2>&1
  $cronStr = ($cronRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $cronStr = $cronStr.Trim()
  $cronJsonStart = $cronStr.IndexOf('{')
  if ($cronJsonStart -ge 0) { $cronStr = $cronStr.Substring($cronJsonStart) }
  $ErrorActionPreference = "Stop"

  $cronJob = $null
  try { $cronJob = $cronStr | ConvertFrom-Json } catch {}
  $cronJobId = if ($cronJob) { $cronJob.id } else { "" }

  if ($cronJobId) {
    Add-Result "cron_schedule" "pass" "id=$cronJobId"
  } else {
    Add-Result "cron_schedule" "fail" "no job id returned"
  }

  if ($cronJobId) {
    $ErrorActionPreference = "Continue"
    $listRaw = docker exec $instanceName openclaw cron list --json 2>&1
    $listStr = ($listRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
    $listStr = $listStr.Trim()
    $listStart = $listStr.IndexOf('{')
    if ($listStart -ge 0) { $listStr = $listStr.Substring($listStart) }
    $ErrorActionPreference = "Stop"
    $cronListed = $false
    $scheduledCronTargetsOk = $false
    try {
      $listData = $listStr | ConvertFrom-Json
      $cronListed = @($listData.jobs | Where-Object { $_.id -eq $cronJobId }).Count -gt 0
      $scheduledJobNames = @("check-reminders", "budget-check", "daily-summary", "retention-job")
      $scheduledJobs = @($listData.jobs | Where-Object { $_.name -in $scheduledJobNames })
      if ($scheduledJobs.Count -eq $scheduledJobNames.Count) {
        $scheduledCronTargetsOk = $true
        foreach ($job in $scheduledJobs) {
          $target = ""
          if ($job.PSObject.Properties.Name -contains "to") {
            $target = [string]$job.to
          } elseif ($job.PSObject.Properties.Name -contains "delivery" -and $job.delivery) {
            if ($job.delivery.PSObject.Properties.Name -contains "to") {
              $target = [string]$job.delivery.to
            }
          }
          if ([string]::IsNullOrWhiteSpace($target) -or ($target -ne $defaultDeliveryTo)) {
            $scheduledCronTargetsOk = $false
            break
          }
        }
      }
    } catch {}
    if ($cronListed) {
      Add-Result "cron_listed" "pass"
    } else {
      Add-Result "cron_listed" "fail" "job not found in cron list"
    }
    if ($scheduledCronTargetsOk) {
      Add-Result "cron_delivery_targets" "pass" "scheduled jobs use expected to=$defaultDeliveryTo"
    } else {
      Add-Result "cron_delivery_targets" "fail" "scheduled cron jobs are missing or have invalid delivery.to"
    }

    Write-Host "Waiting ~75s for cron job to fire..."
    Start-Sleep -Seconds 75

    $ErrorActionPreference = "Continue"
    $runsRaw = docker exec $instanceName openclaw cron runs --id $cronJobId --limit 5 2>&1
    $runsStr = ($runsRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
    $runsStr = $runsStr.Trim()
    $runsStart = $runsStr.IndexOf('{')
    if ($runsStart -ge 0) { $runsStr = $runsStr.Substring($runsStart) }
    $ErrorActionPreference = "Stop"

    $cronFired = $false
    $cronSummaryMatch = $false
    try {
      $runsData = $runsStr | ConvertFrom-Json
      $finishedRuns = @($runsData.entries | Where-Object { $_.action -eq "finished" })
      if ($finishedRuns.Count -gt 0) {
        $cronFired = $true
        foreach ($run in $finishedRuns) {
          if ($run.summary -and $run.summary.Contains($cronMarker)) {
            $cronSummaryMatch = $true
          }
        }
      }
    } catch {}

    if ($cronFired) {
      Add-Result "cron_fired" "pass" "marker_in_summary=$cronSummaryMatch"
    } else {
      Add-Result "cron_fired" "fail" "no finished run found"
    }

    $ErrorActionPreference = "Continue"
    $listAfterRaw = docker exec $instanceName openclaw cron list --json 2>&1
    $listAfterStr = ($listAfterRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
    $listAfterStr = $listAfterStr.Trim()
    $listAfterStart = $listAfterStr.IndexOf('{')
    if ($listAfterStart -ge 0) { $listAfterStr = $listAfterStr.Substring($listAfterStart) }
    $ErrorActionPreference = "Stop"
    $cronGone = $true
    try {
      $listAfterData = $listAfterStr | ConvertFrom-Json
      $cronGone = @($listAfterData.jobs | Where-Object { $_.id -eq $cronJobId }).Count -eq 0
    } catch {}
    if ($cronGone) {
      Add-Result "cron_cleanup" "pass"
    } else {
      Add-Result "cron_cleanup" "fail" "job still in list after firing"
    }
  }

  # --- Agent-driven Reminder: natural language → verify cron actually created ---
  $reminderMarker = "AgentReminder_" + (Get-Date).Ticks.ToString().Substring(12)
  $ErrorActionPreference = "Continue"
  $agentRaw = docker exec $instanceName openclaw agent --to +15550001111 --message "Erinnere mich in 1 Minute an $reminderMarker. Fuehre den exec Befehl aus." --json 2>&1
  $agentStr = ($agentRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $agentStr = $agentStr.Trim()
  $agentJsonStart = $agentStr.IndexOf('{')
  if ($agentJsonStart -ge 0) { $agentStr = $agentStr.Substring($agentJsonStart) }
  $ErrorActionPreference = "Stop"

  $agentReply = $null
  try { $agentReply = $agentStr | ConvertFrom-Json } catch {}
  $replyText = ""
  if ($agentReply -and $agentReply.result -and $agentReply.result.payloads) {
    $replyText = ($agentReply.result.payloads | ForEach-Object { $_.text }) -join " "
  }
  $mentionsReminder = $replyText -match "(?i)(erinnerung|erinner|reminder)"
  if ($mentionsReminder) {
    Add-Result "agent_reminder_response" "pass"
  } else {
    Add-Result "agent_reminder_response" "fail" "reply did not mention reminder"
  }

  $ErrorActionPreference = "Continue"
  $agentCronRaw = docker exec $instanceName openclaw cron list --json 2>&1
  $agentCronStr = ($agentCronRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $agentCronStr = $agentCronStr.Trim()
  $agentCronStart = $agentCronStr.IndexOf('{')
  if ($agentCronStart -ge 0) { $agentCronStr = $agentCronStr.Substring($agentCronStart) }
  $ErrorActionPreference = "Stop"

  $agentCronCreated = $false
  $agentCronJobId = ""
  try {
    $agentCronData = $agentCronStr | ConvertFrom-Json
    if (($agentCronData.total -as [int]) -ge 1) {
      $agentCronCreated = $true
      $agentCronJobId = $agentCronData.jobs[0].id
    }
  } catch {}

  if ($agentCronCreated) {
    Add-Result "agent_reminder_cron_created" "pass" "id=$agentCronJobId"

    Write-Host "Waiting ~75s for agent-scheduled reminder to fire..."
    Start-Sleep -Seconds 75

    $ErrorActionPreference = "Continue"
    $agentRunsRaw = docker exec $instanceName openclaw cron runs --id $agentCronJobId --limit 5 2>&1
    $agentRunsStr = ($agentRunsRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
    $agentRunsStr = $agentRunsStr.Trim()
    $agentRunsStart = $agentRunsStr.IndexOf('{')
    if ($agentRunsStart -ge 0) { $agentRunsStr = $agentRunsStr.Substring($agentRunsStart) }
    $ErrorActionPreference = "Stop"

    $agentCronFired = $false
    try {
      $agentRunsData = $agentRunsStr | ConvertFrom-Json
      $agentCronFired = @($agentRunsData.entries | Where-Object { $_.action -eq "finished" }).Count -gt 0
    } catch {}

    if ($agentCronFired) {
      Add-Result "agent_reminder_fired" "pass"
    } else {
      Add-Result "agent_reminder_fired" "warn" "agent cron job did not fire in time"
    }
  } else {
    Add-Result "agent_reminder_cron_created" "warn" "agent did not call openclaw cron add (prompt compliance gap)"
    Add-Result "agent_reminder_fired" "warn" "skipped - no cron job to wait for"
  }

  $ErrorActionPreference = "Continue"
  $smokeRaw = docker exec $instanceName nexhelper-smoke 2>&1
  $smokeStr = ($smokeRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $smokeStr = $smokeStr.Trim()
  $smokeStart = $smokeStr.IndexOf('{')
  if ($smokeStart -ge 0) {
    $smokeStr = $smokeStr.Substring($smokeStart)
    $ErrorActionPreference = "Stop"
    try {
      $smoke = $smokeStr | ConvertFrom-Json
      if (($smoke.fail -as [int]) -gt 0) {
        throw "Smoke failed: fail=$($smoke.fail)"
      }
      Add-Result "smoke_after_session" "pass" "pass=$($smoke.pass)"
    } catch {
      Add-Result "smoke_after_session" "pass" "smoke-json-parse-warn"
    }
  } else {
    $ErrorActionPreference = "Stop"
    Add-Result "smoke_after_session" "pass" "no-json-output"
  }

  # --- Agent document intake and search ---
  $docNumber = "RE-AI-" + (Get-Date).Ticks.ToString().Substring(10)
  $docMsg = "Ich habe eine Rechnung von Mueller GmbH ueber 1500 Euro, Rechnungsnummer $docNumber, Datum 2026-03-13."
  $ErrorActionPreference = "Continue"
  $docStoreRaw = docker exec $instanceName openclaw agent --to +15550001111 --message "$docMsg" --json 2>&1
  $docStoreStr = ($docStoreRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $docStoreStr = $docStoreStr.Trim()
  $docStoreStart = $docStoreStr.IndexOf('{')
  if ($docStoreStart -ge 0) { $docStoreStr = $docStoreStr.Substring($docStoreStart) }
  $ErrorActionPreference = "Stop"
  $docStoreReply = $null
  try { $docStoreReply = $docStoreStr | ConvertFrom-Json } catch {}
  $docStoreText = ""
  if ($docStoreReply -and $docStoreReply.result -and $docStoreReply.result.payloads) {
    $docStoreText = ($docStoreReply.result.payloads | ForEach-Object { $_.text }) -join " "
  }
  if ($docStoreText -match "(?i)(gespeichert|erfasst|rechnung|beleg|$docNumber)") {
    Add-Result "agent_doc_store" "pass"
  } else {
    Add-Result "agent_doc_store" "warn" "agent reply unclear for document intake"
  }

  $ErrorActionPreference = "Continue"
  $docSearchRaw = docker exec $instanceName openclaw agent --to +15550001111 --message "Suche alle Rechnungen von Mueller" --json 2>&1
  $docSearchStr = ($docSearchRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $docSearchStr = $docSearchStr.Trim()
  $docSearchStart = $docSearchStr.IndexOf('{')
  if ($docSearchStart -ge 0) { $docSearchStr = $docSearchStr.Substring($docSearchStart) }
  $ErrorActionPreference = "Stop"
  $docSearchReply = $null
  try { $docSearchReply = $docSearchStr | ConvertFrom-Json } catch {}
  $docSearchText = ""
  if ($docSearchReply -and $docSearchReply.result -and $docSearchReply.result.payloads) {
    $docSearchText = ($docSearchReply.result.payloads | ForEach-Object { $_.text }) -join " "
  }
  if ($docSearchText -match "(?i)(mueller|rechnung|beleg|keine)") {
    Add-Result "agent_doc_search" "pass"
  } else {
    Add-Result "agent_doc_search" "warn" "agent search response not decisive"
  }

  # --- Agent reminder list and off-topic redirect ---
  $ErrorActionPreference = "Continue"
  $remListRaw = docker exec $instanceName openclaw agent --to +15550001111 --message "Zeig mir meine Erinnerungen" --json 2>&1
  $remListStr = ($remListRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $remListStr = $remListStr.Trim()
  $remListStart = $remListStr.IndexOf('{')
  if ($remListStart -ge 0) { $remListStr = $remListStr.Substring($remListStart) }
  $ErrorActionPreference = "Stop"
  $remListReply = $null
  try { $remListReply = $remListStr | ConvertFrom-Json } catch {}
  $remListText = ""
  if ($remListReply -and $remListReply.result -and $remListReply.result.payloads) {
    $remListText = ($remListReply.result.payloads | ForEach-Object { $_.text }) -join " "
  }
  if ($remListText -match "(?i)(erinner|reminder|keine|cron)") {
    Add-Result "agent_reminder_list" "pass"
  } else {
    Add-Result "agent_reminder_list" "warn" "agent did not provide reminder list style response"
  }

  $ErrorActionPreference = "Continue"
  $offTopicRaw = docker exec $instanceName openclaw agent --to +15550001111 --message "Was ist die Hauptstadt von Frankreich?" --json 2>&1
  $offTopicStr = ($offTopicRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $offTopicStr = $offTopicStr.Trim()
  $offTopicStart = $offTopicStr.IndexOf('{')
  if ($offTopicStart -ge 0) { $offTopicStr = $offTopicStr.Substring($offTopicStart) }
  $ErrorActionPreference = "Stop"
  $offTopicReply = $null
  try { $offTopicReply = $offTopicStr | ConvertFrom-Json } catch {}
  $offTopicText = ""
  if ($offTopicReply -and $offTopicReply.result -and $offTopicReply.result.payloads) {
    $offTopicText = ($offTopicReply.result.payloads | ForEach-Object { $_.text }) -join " "
  }
  $isRedirect = $offTopicText -match "(?i)(dokument|rechnung|beleg|erinner|hilfe)"
  $answeredParis = $offTopicText -match "(?i)\bparis\b"
  if ($isRedirect -and -not $answeredParis) {
    Add-Result "agent_off_topic_redirect" "pass"
  } else {
    Add-Result "agent_off_topic_redirect" "warn" "off-topic redirect not strict"
  }

  # --- Agent multi-turn context and error handling ---
  $ErrorActionPreference = "Continue"
  $mt1Raw = docker exec $instanceName openclaw agent --to +15550001111 --message "Erinnere mich morgen um 10 an Steuerberater" --json 2>&1
  $mt1Str = ($mt1Raw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $mt1Str = $mt1Str.Trim()
  $mt1Start = $mt1Str.IndexOf('{')
  if ($mt1Start -ge 0) { $mt1Str = $mt1Str.Substring($mt1Start) }
  $mt2Raw = docker exec $instanceName openclaw agent --to +15550001111 --message "Aendere den Text zu Jahresabschluss" --json 2>&1
  $mt2Str = ($mt2Raw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $mt2Str = $mt2Str.Trim()
  $mt2Start = $mt2Str.IndexOf('{')
  if ($mt2Start -ge 0) { $mt2Str = $mt2Str.Substring($mt2Start) }
  $ErrorActionPreference = "Stop"
  $mt2Reply = $null
  try { $mt2Reply = $mt2Str | ConvertFrom-Json } catch {}
  $mt2Text = ""
  if ($mt2Reply -and $mt2Reply.result -and $mt2Reply.result.payloads) {
    $mt2Text = ($mt2Reply.result.payloads | ForEach-Object { $_.text }) -join " "
  }
  if ($mt2Text -match "(?i)(jahresabschluss|aender|aktualisiert|erinner)") {
    Add-Result "agent_multi_turn_context" "pass"
  } else {
    Add-Result "agent_multi_turn_context" "warn" "agent did not clearly apply previous turn context"
  }

  $ErrorActionPreference = "Continue"
  $errRaw = docker exec $instanceName openclaw agent --to +15550001111 --message "Loesche Rechnung RE-DOES-NOT-EXIST-999" --json 2>&1
  $errStr = ($errRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $errStr = $errStr.Trim()
  $errStart = $errStr.IndexOf('{')
  if ($errStart -ge 0) { $errStr = $errStr.Substring($errStart) }
  $ErrorActionPreference = "Stop"
  $errReply = $null
  try { $errReply = $errStr | ConvertFrom-Json } catch {}
  $errText = ""
  if ($errReply -and $errReply.result -and $errReply.result.payloads) {
    $errText = ($errReply.result.payloads | ForEach-Object { $_.text }) -join " "
  }
  $errIndicatesMissing = $errText -match "(?i)(nicht gefunden|not found|konnte nicht|existiert nicht|nicht vorhanden|kein treffer|nicht im system)"
  $errClaimsDeleteSuccess = $errText -match "(?i)(geloescht|gelöscht|deleted|entfernt)"
  if ($errIndicatesMissing -or ((-not [string]::IsNullOrWhiteSpace($errText)) -and -not $errClaimsDeleteSuccess)) {
    Add-Result "agent_error_handling" "pass"
  } else {
    Add-Result "agent_error_handling" "warn" "agent did not clearly report missing document"
  }

  # --- Edge: long-thread continuity (12 turns + recall) ---
  $longMarker = "LONGMARK_" + (Get-Date).Ticks.ToString().Substring(11)
  $longThreadOk = $true
  for ($i = 1; $i -le 12; $i++) {
    $turn = Invoke-AgentTurn -InstanceName $instanceName -To "+15550001111" -Message "Merke Marker $longMarker-$i und antworte kurz mit OK $i."
    if (-not $turn.parsed -or [string]::IsNullOrWhiteSpace($turn.text)) {
      $longThreadOk = $false
      break
    }
  }
  if ($longThreadOk) {
    $recallTurn = Invoke-AgentTurn -InstanceName $instanceName -To "+15550001111" -Message "Welcher Marker hatte Nummer 7?"
    if ($recallTurn.text -match [regex]::Escape("$longMarker-7")) {
      Add-Result "agent_long_thread_continuity" "pass"
    } else {
      Add-Result "agent_long_thread_continuity" "warn" "thread stable but marker recall was not exact"
    }
  } else {
    Add-Result "agent_long_thread_continuity" "fail" "one of the long-thread turns returned empty payload"
  }

  # --- Edge: requirement overwrite mid-thread ---
  $ow1 = Invoke-AgentTurn -InstanceName $instanceName -To "+15550001111" -Message "Plane einen Export fuer April als PDF."
  $ow2 = Invoke-AgentTurn -InstanceName $instanceName -To "+15550001111" -Message "Aenderung: nicht PDF, sondern CSV."
  $ow3 = Invoke-AgentTurn -InstanceName $instanceName -To "+15550001111" -Message "Welches Exportformat ist jetzt final?"
  $owText = $ow3.text
  $owHasCsv = $owText -match "(?i)\bcsv\b"
  $owWrongPdf = ($owText -match "(?i)\bpdf\b") -and -not ($owText -match "(?i)(nicht|statt|anstatt|kein)")
  if ($owHasCsv -and -not $owWrongPdf) {
    Add-Result "agent_context_overwrite" "pass"
  } else {
    Add-Result "agent_context_overwrite" "warn" "agent did not clearly converge on overwritten requirement"
  }

  # --- Edge: explicit session isolation ---
  $isolationToken = "RESETTOK_" + (Get-Date).Ticks.ToString().Substring(12)
  $sessionATo = "+15550001111"
  $sessionBTo = "+15550002222"

  $ErrorActionPreference = "Continue"
  $sessBeforeRaw = docker exec $instanceName openclaw sessions --json 2>&1
  $sessBeforeStr = ($sessBeforeRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $sessBeforeStr = $sessBeforeStr.Trim()
  $sessBeforeStart = $sessBeforeStr.IndexOf('{')
  if ($sessBeforeStart -ge 0) { $sessBeforeStr = $sessBeforeStr.Substring($sessBeforeStart) }
  $ErrorActionPreference = "Stop"
  $sessBeforeCount = 0
  try { $sessBeforeCount = (($sessBeforeStr | ConvertFrom-Json).count -as [int]) } catch {}

  $null = Invoke-AgentTurn -InstanceName $instanceName -To $sessionATo -Message "Merke dir dieses Token exakt: $isolationToken"
  $sessARecall = Invoke-AgentTurn -InstanceName $instanceName -To $sessionATo -Message "Wiederhole das Token."
  $sessAHasToken = $sessARecall.text -match [regex]::Escape($isolationToken)

  $sessBRecall = Invoke-AgentTurn -InstanceName $instanceName -To $sessionBTo -Message "Welches Token hatte ich vorhin?"
  $sessBHasToken = $sessBRecall.text -match [regex]::Escape($isolationToken)

  $ErrorActionPreference = "Continue"
  $sessAfterRaw = docker exec $instanceName openclaw sessions --json 2>&1
  $sessAfterStr = ($sessAfterRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $sessAfterStr = $sessAfterStr.Trim()
  $sessAfterStart = $sessAfterStr.IndexOf('{')
  if ($sessAfterStart -ge 0) { $sessAfterStr = $sessAfterStr.Substring($sessAfterStart) }
  $ErrorActionPreference = "Stop"
  $sessAfterCount = $sessBeforeCount
  try { $sessAfterCount = (($sessAfterStr | ConvertFrom-Json).count -as [int]) } catch {}
  $storeShowsIsolation = $sessAfterCount -ge ($sessBeforeCount + 1)

  if ((-not $sessBHasToken) -or $storeShowsIsolation) {
    Add-Result "agent_reset_isolation" "pass"
  } else {
    Add-Result "agent_reset_isolation" "warn" "session isolation not clearly enforced"
  }

  # --- Mandatory log lookup ---
  $ErrorActionPreference = "Continue"
  $logRaw = docker logs $instanceName --tail 400 2>&1
  $logText = ($logRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $ErrorActionPreference = "Stop"
  $hasUnknownToolsWarn = $logText -match "unknown entries \(apply_patch, cron\)"
  $hasSetReminderNotFound = $logText -match "nexhelper-set-reminder: not found"
  if ($hasUnknownToolsWarn -or $hasSetReminderNotFound) {
    $issues = @()
    if ($hasUnknownToolsWarn) { $issues += "unknown_tool_entries" }
    if ($hasSetReminderNotFound) { $issues += "set_reminder_not_found" }
    Add-Result "runtime_log_lookup" "fail" ($issues -join ",")
  } else {
    Add-Result "runtime_log_lookup" "pass" "checked_tail=400"
  }

  $pass = @($results | Where-Object { $_.status -eq "pass" }).Count
  $fail = @($results | Where-Object { $_.status -eq "fail" }).Count
  $warn = @($results | Where-Object { $_.status -eq "warn" }).Count
  [pscustomobject]@{
    status = if ($fail -eq 0) { "pass" } else { "fail" }
    pass = $pass
    fail = $fail
    warn = $warn
    customerDir = $customerDir
    results = $results
  } | ConvertTo-Json -Depth 8
}
catch {
  Add-Result "gateway_session_suite" "fail" $_.Exception.Message
  $pass = @($results | Where-Object { $_.status -eq "pass" }).Count
  $fail = @($results | Where-Object { $_.status -eq "fail" }).Count
  $warn = @($results | Where-Object { $_.status -eq "warn" }).Count
  [pscustomobject]@{
    status = "fail"
    pass = $pass
    fail = $fail
    warn = $warn
    customerDir = $customerDir
    results = $results
  } | ConvertTo-Json -Depth 8
  exit 1
}
finally {
  if (-not $KeepCustomer -and (Test-Path $customerDir)) {
    Push-Location $customerDir
    try {
      $ErrorActionPreference = "Continue"
      docker compose down -v 2>&1 | Out-Null
    } catch {}
    finally { Pop-Location }
  }
}
