# exchangehealth-dashboard.ps1

$Servers = @("SERVER-1","SERVER-2","SERVER-3")
$OutputPath = "C:\inetpub\wwwroot\monitoring\exchangehealth.htm"

# Disk thresholds
$DiskDefaultWarn = 20
$DiskDefaultCrit = 15

# Queue thresholds
$TotalQueueWarn = 50
$TotalQueueCrit = 150
$SingleQueueWarn = 25
$SingleQueueCrit = 75

# Backup thresholds
$BackupWarningDays = 7
$BackupCriticalDays = 10

$now = Get-Date
$nowString = $now.ToString("yyyy-MM-dd HH:mm:ss")

$GlobalStatus = "OK"
$ServerCards = @()

function Set-GlobalStatus {
    param([string]$Status)

    if ($Status -eq "CRITICAL") {
        $script:GlobalStatus = "CRITICAL"
    }
    elseif ($Status -eq "WARNING" -and $script:GlobalStatus -ne "CRITICAL") {
        $script:GlobalStatus = "WARNING"
    }
}

function Get-StatusRank {
    param([string]$Status)

    switch ($Status) {
        "CRITICAL" { return 3 }
        "WARNING"  { return 2 }
        default    { return 1 }
    }
}

function Get-WorstStatus {
    param([string[]]$Statuses)

    $worst = "OK"
    foreach ($s in $Statuses) {
        if ((Get-StatusRank $s) -gt (Get-StatusRank $worst)) {
            $worst = $s
        }
    }
    return $worst
}

# Load Exchange snap-in if needed
try {
    if (-not (Get-Command Get-Queue -ErrorAction SilentlyContinue)) {
        Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction Stop
    }
}
catch {
    # Queue/backup checks will show critical if Exchange cmdlets are unavailable
}

foreach ($server in $Servers) {

    # -----------------------------
    # Disk Health
    # -----------------------------
    $DiskStatus = "OK"
    $DiskSummary = "All monitored disks OK"

    try {
        $drives = Get-WmiObject Win32_LogicalDisk -ComputerName $server -Filter "DriveType=3" -ErrorAction Stop

        $diskFindings = @()

        foreach ($d in $drives) {
            if ($null -eq $d.Size -or $d.Size -eq 0) { continue }

            $freePercent = [math]::Round(($d.FreeSpace / $d.Size) * 100, 1)
            $label = if ([string]::IsNullOrWhiteSpace($d.VolumeName)) { "NoLabel" } else { $d.VolumeName }

            $warn = $DiskDefaultWarn
            $crit = $DiskDefaultCrit

            switch -Wildcard ($label.ToUpper()) {
                "*OS*"    { $warn = 20; $crit = 15 }
                "*DB*"    { $warn = 25; $crit = 20 }
                "*LOG*"   { $warn = 30; $crit = 20 }
                "*QUEUE*" { $warn = 25; $crit = 15 }
            }

            if ($freePercent -lt $crit) {
                $DiskStatus = "CRITICAL"
                $diskFindings += "$label critical"
            }
            elseif ($freePercent -lt $warn -and $DiskStatus -ne "CRITICAL") {
                $DiskStatus = "WARNING"
                $diskFindings += "$label warning"
            }
        }

        if ($diskFindings.Count -gt 0) {
            $DiskSummary = ($diskFindings -join ", ")
        }
    }
    catch {
        $DiskStatus = "CRITICAL"
        $DiskSummary = "Unable to query disks"
    }

    # -----------------------------
    # Queue Health
    # -----------------------------
    $QueueStatus = "OK"
    $QueueSummary = "Queues OK"

    try {
        $queues = Get-Queue -Server $server -ErrorAction Stop

        $totalMessages = ($queues | Measure-Object MessageCount -Sum).Sum
        if ($null -eq $totalMessages) { $totalMessages = 0 }

        $maxSingleQueue = ($queues | Measure-Object MessageCount -Maximum).Maximum
        if ($null -eq $maxSingleQueue) { $maxSingleQueue = 0 }

        $badQueueState = $queues | Where-Object {
            $_.Status -in @("Retry","Suspended")
        }

        if ($totalMessages -ge $TotalQueueCrit -or $maxSingleQueue -ge $SingleQueueCrit -or $badQueueState) {
            $QueueStatus = "CRITICAL"
        }
        elseif ($totalMessages -ge $TotalQueueWarn -or $maxSingleQueue -ge $SingleQueueWarn) {
            $QueueStatus = "WARNING"
        }

        $QueueSummary = "Total: $totalMessages, largest queue: $maxSingleQueue"
    }
    catch {
        $QueueStatus = "CRITICAL"
        $QueueSummary = "Unable to query queues"
    }

    # -----------------------------
    # Backup Health
    # -----------------------------
    $BackupStatus = "OK"
    $BackupSummary = "Backups recent"

    try {
        $dbs = Get-MailboxDatabase -Server $server -Status -ErrorAction Stop
        $backupFindings = @()

        foreach ($db in $dbs) {
            $lastBackup = $db.LastFullBackup
            if (-not $lastBackup) {
                $lastBackup = $db.LastIncrementalBackup
            }

            if (-not $lastBackup) {
                $BackupStatus = "CRITICAL"
                $backupFindings += "database has no backup timestamp"
                continue
            }

            $ageDays = [math]::Round(($now - $lastBackup).TotalDays, 1)

            if ($ageDays -ge $BackupCriticalDays) {
                $BackupStatus = "CRITICAL"
                $backupFindings += "backup older than $BackupCriticalDays days"
            }
            elseif ($ageDays -ge $BackupWarningDays -and $BackupStatus -ne "CRITICAL") {
                $BackupStatus = "WARNING"
                $backupFindings += "backup older than $BackupWarningDays days"
            }
        }

        if ($backupFindings.Count -gt 0) {
            $BackupSummary = ($backupFindings | Select-Object -Unique) -join ", "
        }
    }
    catch {
        $BackupStatus = "CRITICAL"
        $BackupSummary = "Unable to query backup status"
    }

    $ServerStatus = Get-WorstStatus @($DiskStatus, $QueueStatus, $BackupStatus)
    Set-GlobalStatus $ServerStatus

    $ServerCards += @"
<div class="card $ServerStatus">
  <div class="card-header">
    <h2>$server</h2>
    <span class="badge $ServerStatus">$ServerStatus</span>
  </div>

  <div class="check">
    <span class="label">Disk</span>
    <span class="badge $DiskStatus">$DiskStatus</span>
    <p>$DiskSummary</p>
  </div>

  <div class="check">
    <span class="label">Queue</span>
    <span class="badge $QueueStatus">$QueueStatus</span>
    <p>$QueueSummary</p>
  </div>

  <div class="check">
    <span class="label">Backup</span>
    <span class="badge $BackupStatus">$BackupStatus</span>
    <p>$BackupSummary</p>
  </div>
</div>
"@
}

$html = @"
<!doctype html>
<html>
<head>
<title>Exchange Health Dashboard</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="300">
<style>
:root {
  --bg: #101214;
  --panel: #181b1f;
  --border: #2d333a;
  --text: #f2f2f2;
  --muted: #a8b0b8;
  --ok: #37c96b;
  --warning: #f2c94c;
  --critical: #ff5c5c;
}

* {
  box-sizing: border-box;
}

body {
  margin: 0;
  padding: 16px;
  font-family: Arial, sans-serif;
  background: var(--bg);
  color: var(--text);
}

.header {
  margin-bottom: 18px;
}

.header h1 {
  margin: 0 0 8px 0;
  font-size: 1.6rem;
}

.meta {
  color: var(--muted);
  font-size: 0.9rem;
  margin-top: 8px;
}

.grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 14px;
}

.card {
  background: var(--panel);
  border: 1px solid var(--border);
  border-left: 6px solid var(--ok);
  border-radius: 12px;
  padding: 14px;
}

.card.WARNING {
  border-left-color: var(--warning);
}

.card.CRITICAL {
  border-left-color: var(--critical);
}

.card-header {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  align-items: center;
  margin-bottom: 12px;
}

.card h2 {
  margin: 0;
  font-size: 1.25rem;
}

.check {
  border-top: 1px solid var(--border);
  padding-top: 10px;
  margin-top: 10px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.label {
  font-weight: bold;
}

.check p {
  display: none;
}

.badge,
.summary {
  display: inline-block;
  min-width: 74px;
  text-align: center;
  padding: 5px 8px;
  border-radius: 999px;
  font-weight: bold;
  font-size: 0.8rem;
  color: #111;
}

.summary {
  min-width: auto;
  font-size: 0.95rem;
}

.badge.OK,
.summary.OK {
  background: var(--ok);
}

.badge.WARNING,
.summary.WARNING {
  background: var(--warning);
}

.badge.CRITICAL,
.summary.CRITICAL {
  background: var(--critical);
}

@media (max-width: 520px) {
  body {
    padding: 12px;
  }

  .header h1 {
    font-size: 1.35rem;
  }

  .card {
    border-radius: 10px;
  }
}
</style>
</head>
<body>

<div class="header">
  <h1>Exchange Health Dashboard</h1>
  <div class="summary $GlobalStatus">Overall Status: $GlobalStatus</div>
  <div class="meta">Last updated: $nowString</div>
</div>

<div class="grid">
$($ServerCards -join "`n")
</div>

</body>
</html>
"@

$folder = Split-Path $OutputPath
if (-not (Test-Path $folder)) {
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
}

$html | Out-File $OutputPath -Encoding UTF8

Write-Output "Exchange dashboard written to $OutputPath with status $GlobalStatus"
