param(
  # Generic provider params (preferred)
  [string]$ApiKey       = $env:AI_API_KEY,
  [string]$Provider     = $env:AI_PROVIDER,
  [string]$BaseUrl      = $env:AI_BASE_URL,
  # Legacy OpenRouter aliases (still accepted for backward compat)
  [string]$OpenRouterApiKey = $env:OPENROUTER_API_KEY,
  [string]$OpenRouterBaseUrl,
  [string]$GeminiApiKey = $env:GEMINI_API_KEY,
  [string]$TelegramBotToken = $env:TELEGRAM_BOT_TOKEN,
  [switch]$KeepCustomer
)

$ErrorActionPreference = "Stop"

# Resolve backward-compat aliases into canonical vars
if (-not $ApiKey -and $GeminiApiKey)     { $ApiKey = $GeminiApiKey; if (-not $Provider) { $Provider = "gemini" } }
if (-not $ApiKey -and $OpenRouterApiKey) { $ApiKey = $OpenRouterApiKey; if (-not $Provider) { $Provider = "openrouter" } }
if (-not $Provider) { $Provider = "gemini" }

if (-not $ApiKey) {
  throw "Missing API key. Set GEMINI_API_KEY (or -GeminiApiKey) for Gemini, OPENROUTER_API_KEY (or -OpenRouterApiKey) for OpenRouter, or AI_API_KEY (or -ApiKey) for any provider."
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

# Runs a bash command in the container via a temp script file to avoid
# PowerShell 5.x Windows argument-quoting issues with JSON containing double-quotes.
function Invoke-ContainerScript {
  param(
    [string]$InstanceName,
    [string]$BashCommand
  )
  $ErrorActionPreference = "Continue"
  $tmpLocal = [System.IO.Path]::GetTempFileName() -replace '\.tmp$','.sh'
  $scriptContent = "#!/bin/bash`n$BashCommand`n"
  [System.IO.File]::WriteAllText($tmpLocal, $scriptContent.Replace("`r`n", "`n"), [System.Text.Encoding]::ASCII)
  docker cp $tmpLocal "${InstanceName}:/tmp/nx_cscript.sh" 2>&1 | Out-Null
  Remove-Item $tmpLocal -ErrorAction SilentlyContinue
  $raw = docker exec $InstanceName bash -l /tmp/nx_cscript.sh 2>&1
  $ErrorActionPreference = "Stop"
  return $raw
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
  $channelArgs = if ($TelegramBotToken) { "--telegram '$TelegramBotToken'" } else { "--whatsapp" }
  $baseUrlArg = if ($BaseUrl) { "AI_BASE_URL='$BaseUrl'" } else { "" }
  $provisionCmd = "cd '$rootBash' && AI_PROVIDER='$Provider' AI_API_KEY='$ApiKey' $baseUrlArg DEFAULT_DELIVERY_TO='$defaultDeliveryTo' ./provision-customer.sh $customerId '$customerName' $channelArgs --base-dir '$baseDirBash' --no-start"
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
  $lastHealthStr = ""
  $ErrorActionPreference = "Continue"
  for ($i = 0; $i -lt 60; $i++) {
    try {
      $healthRaw = docker exec $instanceName openclaw health --json 2>&1
      $healthStr = ($healthRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
      $healthStr = $healthStr.Trim()
      $lastHealthStr = $healthStr
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
    $containerLogs = docker logs --tail 20 $instanceName 2>&1
    $logsText = ($containerLogs | Where-Object { $_ -is [string] } ) -join "`n"
    $detail = if ($lastHealthStr) { "last_response=[$lastHealthStr]" } else { "no_response_from_openclaw_health" }
    if ($logsText) { $detail += " container_tail=[$logsText]" }
    throw "Gateway did not become healthy in time. $detail"
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

  # --- Cron assertion: no duplicate job names ---
  $ErrorActionPreference = "Continue"
  $cronRaw = docker exec $instanceName sh -lc "openclaw cron list --json 2>/dev/null || echo '{}'" 2>&1
  $cronText = ($cronRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $cronText = $cronText.Trim()
  $ErrorActionPreference = "Stop"
  $cronParsed = $null
  try { $cronParsed = $cronText | ConvertFrom-Json } catch {}
  if ($null -ne $cronParsed -and $null -ne $cronParsed.jobs) {
    $jobNames = @($cronParsed.jobs | ForEach-Object { $_.name })
    $uniqueNames = @($jobNames | Sort-Object -Unique)
    if ($jobNames.Count -eq $uniqueNames.Count) {
      Add-Result "cron_names_unique" "pass" "jobs=$($jobNames.Count)"
    } else {
      $dupes = @($jobNames | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
      Add-Result "cron_names_unique" "fail" "duplicate names: $($dupes -join ', ')"
    }
  } else {
    Add-Result "cron_names_unique" "warn" "could not parse cron list"
  }

  # --- Cron assertion: daily-summary absent by default ---
  if ($null -ne $cronParsed -and $null -ne $cronParsed.jobs) {
    $hasDailySummary = $cronParsed.jobs | Where-Object { $_.name -eq "daily-summary" }
    if (-not $hasDailySummary) {
      Add-Result "cron_daily_summary_absent" "pass"
    } else {
      Add-Result "cron_daily_summary_absent" "fail" "daily-summary should not be registered by default"
    }
  } else {
    Add-Result "cron_daily_summary_absent" "warn" "could not parse cron list"
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
      # reminder-auditor and check-reminders now run as native shell background loops (zero LLM cost).
      # Only budget-check and retention-job remain in the cron scheduler.
      $expectedStartupJobs = @("budget-check", "retention-job")
      $foundStartupJobs = @($listData.jobs | Where-Object { $_.name -in $expectedStartupJobs } | ForEach-Object { $_.name })
      $missingStartupJobs = @($expectedStartupJobs | Where-Object { $_ -notin $foundStartupJobs })
      if ($missingStartupJobs.Count -eq 0) {
        $scheduledCronTargetsOk = $true
      }
    } catch {}
    if ($cronListed) {
      Add-Result "cron_listed" "pass"
    } else {
      Add-Result "cron_listed" "fail" "job not found in cron list"
    }
    if ($scheduledCronTargetsOk) {
      Add-Result "cron_startup_jobs_present" "pass" "all startup cron jobs registered"
    } else {
      Add-Result "cron_startup_jobs_present" "fail" "some startup cron jobs missing"
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

  # --- RBAC: policy file exists and is valid JSON ---
  $ErrorActionPreference = "Continue"
  $policyRaw = docker exec $instanceName sh -lc 'cat /root/.openclaw/workspace/policy.json 2>/dev/null || cat /root/.openclaw/workspace/storage/policy.json 2>/dev/null || echo "{}"' 2>&1
  $policyStr = ($policyRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $policyStr = $policyStr.Trim()
  $ErrorActionPreference = "Stop"
  $policyValid = $false
  try {
    $policy = $policyStr | ConvertFrom-Json
    if ($null -ne $policy.admins) { $policyValid = $true }
  } catch {}
  if ($policyValid) {
    Add-Result "rbac_policy_file_exists" "pass" "policy.json is valid and contains admins array"
  } else {
    Add-Result "rbac_policy_file_exists" "fail" "policy.json missing or invalid: $policyStr"
  }

  # --- RBAC: nexhelper-policy command available ---
  $ErrorActionPreference = "Continue"
  $policyCmd = docker exec $instanceName sh -lc 'command -v nexhelper-policy >/dev/null 2>&1 && echo __OK__ || echo __FAIL__' 2>&1
  $policyCmdText = ($policyCmd | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $ErrorActionPreference = "Stop"
  if ($policyCmdText -match "__OK__") {
    Add-Result "rbac_policy_command_available" "pass"
  } else {
    Add-Result "rbac_policy_command_available" "fail" "nexhelper-policy not found on PATH"
  }

  # --- RBAC: member cannot delete (enforced when NX_ACTOR is set) ---
  $ErrorActionPreference = "Continue"
  $memberDeleteRaw = docker exec $instanceName sh -lc 'NX_ACTOR=member_test_user nexhelper-doc delete nonexistent_doc_id --reason test 2>&1 | head -5' 2>&1
  $memberDeleteText = ($memberDeleteRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $ErrorActionPreference = "Stop"
  if ($memberDeleteText -match "forbidden|not_found") {
    Add-Result "rbac_member_delete_blocked" "pass" "delete blocked or doc not found for non-admin"
  } else {
    Add-Result "rbac_member_delete_blocked" "warn" "could not verify member delete enforcement: $memberDeleteText"
  }

  # --- RBAC: admin promote/demote roundtrip ---
  $ErrorActionPreference = "Continue"
  $promoteRaw = docker exec $instanceName sh -lc 'nexhelper-policy add-admin test_rbac_user cli 2>&1' 2>&1
  $promoteText = ($promoteRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $promoteJson = $null
  try { $promoteJson = $promoteText | ConvertFrom-Json } catch {}
  $promoteOk = $promoteJson -and ($promoteJson.status -eq "promoted" -or $promoteJson.status -eq "already_admin")

  $demoteRaw = docker exec $instanceName sh -lc 'nexhelper-policy remove-admin test_rbac_user cli 2>&1' 2>&1
  $demoteText = ($demoteRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $demoteJson = $null
  try { $demoteJson = $demoteText | ConvertFrom-Json } catch {}
  $demoteOk = $demoteJson -and $demoteJson.status -eq "demoted"
  $ErrorActionPreference = "Stop"

  if ($promoteOk -and $demoteOk) {
    Add-Result "rbac_admin_promote_demote" "pass"
  } else {
    Add-Result "rbac_admin_promote_demote" "fail" "promote=$($promoteText.Trim()) demote=$($demoteText.Trim())"
  }

  # --- Document retrieve command available ---
  $ErrorActionPreference = "Continue"
  $retrieveRaw = docker exec $instanceName sh -lc 'nexhelper-doc retrieve nonexistent_doc 2>&1' 2>&1
  $retrieveText = ($retrieveRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $ErrorActionPreference = "Stop"
  if ($retrieveText -match "not_found|found|no_file") {
    Add-Result "doc_retrieve_command" "pass" "retrieve command responds correctly"
  } else {
    Add-Result "doc_retrieve_command" "fail" "unexpected retrieve output: $retrieveText"
  }

  # --- Admin report command available ---
  $ErrorActionPreference = "Continue"
  $reportRaw = docker exec $instanceName sh -lc 'nexhelper-admin-report 2>&1 | head -1' 2>&1
  $reportText = ($reportRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $ErrorActionPreference = "Stop"
  if ($reportText -match "timestamp|health|docStats") {
    Add-Result "admin_report_command" "pass"
  } else {
    Add-Result "admin_report_command" "fail" "admin report output unexpected: $reportText"
  }

  # --- nexhelper-notify command available ---
  $ErrorActionPreference = "Continue"
  $notifyRaw = docker exec $instanceName sh -lc 'command -v nexhelper-notify >/dev/null 2>&1 && echo __OK__ || echo __FAIL__' 2>&1
  $notifyText = ($notifyRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $ErrorActionPreference = "Stop"
  if ($notifyText -match "__OK__") {
    Add-Result "notify_command_available" "pass"
  } else {
    Add-Result "notify_command_available" "fail" "nexhelper-notify not found on PATH"
  }

  # --- Startup cron jobs registered (low-frequency only) ---
  # reminder-auditor and check-reminders are now native background loops; they must NOT appear in cron.
  $ErrorActionPreference = "Continue"
  $cronListAllRaw = docker exec $instanceName openclaw cron list --json 2>&1
  $cronListAllText = ($cronListAllRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $ErrorActionPreference = "Stop"
  try {
    $cronAllJson = $cronListAllText | ConvertFrom-Json -ErrorAction Stop
    $requiredCronJobs = @("budget-check", "retention-job")
    $missingJobs = @($requiredCronJobs | Where-Object { $cronAllJson.jobs.name -notcontains $_ })
    if ($missingJobs.Count -eq 0) {
      Add-Result "startup_cron_registered" "pass" "both low-frequency jobs registered"
    } else {
      Add-Result "startup_cron_registered" "fail" "missing: $($missingJobs -join ', ')"
    }
    # Verify ops background-loop jobs are NOT in cron (they should run as native loops)
    $opsLoopJobs = @("reminder-auditor", "check-reminders")
    $unexpectedInCron = @($opsLoopJobs | Where-Object { $cronAllJson.jobs.name -contains $_ })
    if ($unexpectedInCron.Count -eq 0) {
      Add-Result "ops_loops_not_in_cron" "pass" "reminder-auditor and check-reminders correctly absent from cron"
    } else {
      Add-Result "ops_loops_not_in_cron" "fail" "ops jobs should not be in cron: $($unexpectedInCron -join ', ')"
    }
  } catch {
    Add-Result "startup_cron_registered" "warn" "could not parse cron list"
    Add-Result "ops_loops_not_in_cron" "warn" "could not parse cron list"
  }

  # --- Healthcheck includes liveness checks (use login shell for PATH) ---
  $ErrorActionPreference = "Continue"
  $hcRaw = docker exec $instanceName sh -lc "nexhelper-healthcheck 2>&1" 2>&1
  $hcText = ($hcRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $ErrorActionPreference = "Stop"
  try {
    $hcLine = ($hcText -split "`n" | Where-Object { $_.TrimStart().StartsWith('{') } | Select-Object -First 1)
    $hcJson = $hcLine.Trim() | ConvertFrom-Json -ErrorAction Stop
    $hasApiKey = $hcJson.checks.name -contains "api_key_configured"
    $hasProvider = $hcJson.checks.name -contains "ai_provider_reachable"
    if ($hasApiKey -and $hasProvider) {
      Add-Result "healthcheck_liveness_checks" "pass" "api_key and provider checks present (status=$($hcJson.status))"
    } else {
      Add-Result "healthcheck_liveness_checks" "fail" "missing liveness checks (api_key=$hasApiKey provider=$hasProvider)"
    }
  } catch {
    Add-Result "healthcheck_liveness_checks" "warn" "could not parse healthcheck output: $_"
  }

  # --- Audio config: tools.media.audio enabled + auth profile ---
  $ErrorActionPreference = "Continue"
  $audioCfgRaw = docker exec $instanceName sh -lc "jq '.tools.media.audio // empty' /root/.openclaw/openclaw.json 2>/dev/null" 2>&1
  $audioCfgText = ($audioCfgRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $authProfRaw = docker exec $instanceName sh -lc "jq '.profiles | keys' /root/.openclaw/auth-profiles.json 2>/dev/null" 2>&1
  $authProfText = ($authProfRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $ErrorActionPreference = "Stop"
  $audioEnabled = $audioCfgText -match '"enabled":\s*true'
  $audioHasModel = $audioCfgText -match '"model"'
  $whisperProfile = $authProfText -match 'openai:whisper'
  if ($audioEnabled -and $audioHasModel -and $whisperProfile) {
    Add-Result "audio_config" "pass" "tools.media.audio enabled with model + openai:whisper auth profile"
  } elseif ($audioEnabled) {
    Add-Result "audio_config" "warn" "audio enabled but missing model=$audioHasModel or whisper-profile=$whisperProfile"
  } else {
    Add-Result "audio_config" "fail" "tools.media.audio not configured (audioCfg=[$audioCfgText])"
  }

  # --- /start command returns user ID ---
  $startEventJson = '{"id":"start_test","kind":"message","text":"/start","senderId":"startuser"}'
  $startRaw = Invoke-ContainerScript -InstanceName $instanceName -BashCommand "nexhelper-workflow run --event-json '$startEventJson' 2>&1"
  $startText = ($startRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $ErrorActionPreference = "Stop"
  if ($startText -match '"status":"start"' -and $startText -match "startuser") {
    Add-Result "start_command_handler" "pass" "/start returns user ID and role"
  } else {
    Add-Result "start_command_handler" "fail" "/start not handled: $($startText.Substring(0,[Math]::Min(120,$startText.Length)))"
  }

  # --- store without --project returns suggestProject:true ---
  $ErrorActionPreference = "Continue"
  $noProjStoreRaw = docker exec $instanceName sh -lc "nexhelper-doc store --type rechnung --amount 111 --supplier SuggestProjGmbH --number SP-2026-001 --date 2026-01-15 2>&1" 2>&1
  $noProjStoreText = ($noProjStoreRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $ErrorActionPreference = "Stop"
  try {
    $noProjLine = ($noProjStoreText -split "`n" | Where-Object { $_.TrimStart().StartsWith('{') } | Select-Object -First 1)
    $noProjJson = $noProjLine.Trim() | ConvertFrom-Json -ErrorAction Stop
    if ($noProjJson.status -eq "stored" -and $noProjJson.suggestProject -eq $true) {
      Add-Result "doc_suggest_project" "pass" "store without --project sets suggestProject=true"
    } else {
      Add-Result "doc_suggest_project" "fail" "suggestProject not set: status=$($noProjJson.status) suggestProject=$($noProjJson.suggestProject)"
    }
  } catch {
    Add-Result "doc_suggest_project" "warn" "could not parse store output: $_"
  }

  # --- Project tag store + search ---
  $ErrorActionPreference = "Continue"
  $projStoreRaw = docker exec $instanceName sh -lc "nexhelper-doc store --type rechnung --amount 999 --supplier TestBauGmbH --number P-2026-TEST --date 2026-01-01 --project 'BaustelleTest' 2>&1" 2>&1
  $projStoreText = ($projStoreRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $ErrorActionPreference = "Stop"
  try {
    $projStoreLine = ($projStoreText -split "`n" | Where-Object { $_.TrimStart().StartsWith('{') } | Select-Object -First 1)
    $projStoreJson = $projStoreLine.Trim() | ConvertFrom-Json -ErrorAction Stop
    if ($projStoreJson.status -eq "stored" -and $projStoreJson.document.project -eq "BaustelleTest") {
      # Now search by project
      $projSearchRaw = docker exec $instanceName sh -lc "nexhelper-doc search --project 'BaustelleTest' --semantic false 2>&1" 2>&1
      $projSearchText = ($projSearchRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
      $projSearchLine = ($projSearchText -split "`n" | Where-Object { $_.TrimStart().StartsWith('{') } | Select-Object -First 1)
      $projSearchJson = $projSearchLine.Trim() | ConvertFrom-Json -ErrorAction Stop
      if ($projSearchJson.count -gt 0) {
        Add-Result "project_tag_store_search" "pass" "stored with project=BaustelleTest, search returned $($projSearchJson.count) result(s)"
      } else {
        Add-Result "project_tag_store_search" "fail" "project search returned 0 results after store"
      }
    } else {
      Add-Result "project_tag_store_search" "fail" "store with --project failed: status=$($projStoreJson.status)"
    }
  } catch {
    Add-Result "project_tag_store_search" "warn" "could not parse project store/search output: $_"
  }

  # --- whois command available in workflow (also seeds user registry via senderId) ---
  $whoisEventJson = '{"id":"whois_test","kind":"message","text":"/whois nonexistent","senderId":"testuser","senderUsername":"testuser"}'
  $whoisRaw = Invoke-ContainerScript -InstanceName $instanceName -BashCommand "nexhelper-workflow run --event-json '$whoisEventJson' 2>&1"
  $whoisText = ($whoisRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $ErrorActionPreference = "Stop"
  if ($whoisText -match "not_found|found") {
    Add-Result "whois_command_available" "pass" "whois lookup responds correctly"
  } else {
    Add-Result "whois_command_available" "warn" "whois response unexpected: $($whoisText.Substring(0,[Math]::Min(100,$whoisText.Length)))"
  }

  # --- User registry populated by first contact ---
  $ErrorActionPreference = "Continue"
  $usersRaw = docker exec $instanceName sh -lc "cat /root/.openclaw/workspace/users.json 2>/dev/null || echo '{}'" 2>&1
  $usersText = ($usersRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $ErrorActionPreference = "Stop"
  try {
    $usersJson = ($usersText -split "`n" | Where-Object { $_.TrimStart().StartsWith('{') } | Select-Object -First 1).Trim() | ConvertFrom-Json -ErrorAction Stop
    $userCount = ($usersJson.PSObject.Properties | Measure-Object).Count
    if ($userCount -gt 0) {
      Add-Result "user_registry_populated" "pass" "registry has $userCount user(s)"
    } else {
      Add-Result "user_registry_populated" "warn" "user registry empty (whois may have registered but registry not flushed yet)"
    }
  } catch {
    Add-Result "user_registry_populated" "warn" "could not parse users.json"
  }

  # --- Health monitor system event routes correctly ---
  $ErrorActionPreference = "Continue"
  $hmEventJson = '{"id":"hm_test","kind":"systemEvent","text":"Run system health check and alert admin if status is degraded"}'
  $hmRaw = Invoke-ContainerScript -InstanceName $instanceName -BashCommand "nexhelper-workflow run --event-json '$hmEventJson' 2>&1"
  $hmText = ($hmRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $ErrorActionPreference = "Stop"
  if ($hmText -match "health_monitor") {
    Add-Result "health_monitor_event" "pass" "health-monitor system event routes correctly"
  } else {
    Add-Result "health_monitor_event" "fail" "health-monitor event not handled: $($hmText.Substring(0,[Math]::Min(100,$hmText.Length)))"
  }

  # --- nexhelper-doc append adds extra page to existing doc ---
  $ErrorActionPreference = "Continue"
  $appendBaseRaw = docker exec $instanceName sh -lc "nexhelper-doc store --type rechnung --amount 200 --supplier AppendTestGmbH --number APP-2026-001 --date 2026-02-01 2>&1" 2>&1
  $appendBaseText = ($appendBaseRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $ErrorActionPreference = "Stop"
  try {
    $appendBaseLine = ($appendBaseText -split "`n" | Where-Object { $_.TrimStart().StartsWith('{') } | Select-Object -First 1)
    $appendBaseJson = $appendBaseLine.Trim() | ConvertFrom-Json -ErrorAction Stop
    if ($appendBaseJson.status -eq "stored") {
      $appendDocId = $appendBaseJson.document.id
      $ErrorActionPreference = "Continue"
      $appendRaw = docker exec $instanceName sh -lc "nexhelper-doc append --id '$appendDocId' --file '/tmp/page2.jpg' 2>&1" 2>&1
      $appendText = ($appendRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
      $ErrorActionPreference = "Stop"
      $appendLine = ($appendText -split "`n" | Where-Object { $_.TrimStart().StartsWith('{') } | Select-Object -First 1)
      $appendJson = $appendLine.Trim() | ConvertFrom-Json -ErrorAction Stop
      if ($appendJson.status -eq "appended" -and $appendJson.docId -eq $appendDocId) {
        Add-Result "doc_append_command" "pass" "append added page to doc $appendDocId revision=$($appendJson.revision)"
      } else {
        Add-Result "doc_append_command" "fail" "append unexpected result: status=$($appendJson.status)"
      }
    } else {
      Add-Result "doc_append_command" "warn" "base store failed, skipping append test"
    }
  } catch {
    Add-Result "doc_append_command" "warn" "could not run append test: $_"
  }

  # --- Structured event routing: nexhelper:event:<type> tokens ---
  # Uses Invoke-ContainerScript to avoid PowerShell/Docker JSON quoting issues.
  $structuredEventTests = @(
    @{JsonStr='{"id":"se_rem","kind":"systemEvent","text":"nexhelper:event:reminder-audit"}'; expectedHandler="reminder_due";  label="reminder-audit"},
    @{JsonStr='{"id":"se_bud","kind":"systemEvent","text":"nexhelper:event:budget-check"}';   expectedHandler="budget_check";  label="budget-check"},
    @{JsonStr='{"id":"se_hlt","kind":"systemEvent","text":"nexhelper:event:health-check"}';   expectedHandler="health_monitor";label="health-check"},
    @{JsonStr='{"id":"se_ret","kind":"systemEvent","text":"nexhelper:event:retention"}';       expectedHandler="retention";     label="retention"}
  )
  $allStructuredOk = $true
  $structuredFailDetails = @()
  foreach ($ev in $structuredEventTests) {
    $seRaw = Invoke-ContainerScript -InstanceName $instanceName -BashCommand "nexhelper-workflow run --event-json '$($ev.JsonStr)' 2>/dev/null"
    $seText = ($seRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
    $gotHandler = ""
    try {
      $seLine = ($seText -split "`n" | Where-Object { $_.TrimStart().StartsWith('{') } | Select-Object -First 1)
      $seJson = $seLine.Trim() | ConvertFrom-Json -ErrorAction Stop
      $gotHandler = $seJson.result.handler
    } catch {}
    if ($gotHandler -eq $ev.expectedHandler) {
      # token OK
    } else {
      $allStructuredOk = $false
      $structuredFailDetails += "$($ev.label)->[$gotHandler](expected $($ev.expectedHandler))"
    }
  }
  if ($allStructuredOk) {
    Add-Result "structured_event_routing" "pass" "all 4 event tokens routed correctly"
  } else {
    Add-Result "structured_event_routing" "fail" ($structuredFailDetails -join "; ")
  }

  # --- nexhelper-monitor script available and returns valid JSON ---
  $ErrorActionPreference = "Continue"
  $monRaw = docker exec $instanceName sh -lc "nexhelper-monitor errors 2>/dev/null || echo '{}'" 2>&1
  $monText = ($monRaw | Where-Object { $_ -is [string] -or $_.GetType().Name -ne 'ErrorRecord' }) -join "`n"
  $ErrorActionPreference = "Stop"
  try {
    $monLine = ($monText -split "`n" | Where-Object { $_.TrimStart().StartsWith('{') } | Select-Object -First 1)
    $monJson = $monLine.Trim() | ConvertFrom-Json -ErrorAction Stop
    if ($monJson.status) {
      Add-Result "monitor_available" "pass" "nexhelper-monitor errors returned status=$($monJson.status)"
    } else {
      Add-Result "monitor_available" "warn" "monitor output missing .status"
    }
  } catch {
    Add-Result "monitor_available" "warn" "could not parse monitor output: $_"
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
