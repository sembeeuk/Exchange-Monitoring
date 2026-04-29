# backuphealth-public.ps1

$Servers = @("SERVER-1","SERVER-2","SERVER-3")
$OutputPath = "C:\inetpub\wwwroot\monitoring\backuphealth.htm"

# Set your threshold here (days)
$WarningDays = 7
$CriticalDays = 10

$now = Get-Date
$nowString = $now.ToString("yyyy-MM-dd HH:mm:ss")

$globalStatus = "OK"
$rows = @()

# Load Exchange snap-in if required
try {
    if (-not (Get-Command Get-MailboxDatabase -ErrorAction SilentlyContinue)) {
        Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction Stop
    }
}
catch {
    $globalStatus = "CRITICAL"
}

foreach ($server in $Servers) {

    $serverStatus = "OK"

    try {
        $dbs = Get-MailboxDatabase -Server $server -Status -ErrorAction Stop
    }
    catch {
        $serverStatus = "CRITICAL"
    }

    if ($serverStatus -ne "CRITICAL") {
        foreach ($db in $dbs) {

            # Prefer full backup, fall back to incremental
            $lastBackup = $db.LastFullBackup
            if (-not $lastBackup) {
                $lastBackup = $db.LastIncrementalBackup
            }

            if (-not $lastBackup) {
                $serverStatus = "CRITICAL"
                break
            }

            $ageDays = ($now - $lastBackup).TotalDays

            if ($ageDays -ge $CriticalDays) {
                $serverStatus = "CRITICAL"
                break
            }
            elseif ($ageDays -ge $WarningDays -and $serverStatus -ne "CRITICAL") {
                $serverStatus = "WARNING"
            }
        }
    }

    if ($serverStatus -eq "CRITICAL") {
        $globalStatus = "CRITICAL"
    }
    elseif ($serverStatus -eq "WARNING" -and $globalStatus -ne "CRITICAL") {
        $globalStatus = "WARNING"
    }

    $rows += "<tr><td>$server</td><td class='$serverStatus'>$serverStatus</td></tr>"
}

$statusLine = "<!-- EXCHANGE-BACKUP-STATUS: $globalStatus -->"

$html = @"
<!doctype html>
<html>
<head>
<title>Exchange Backup Health</title>
<meta http-equiv="refresh" content="300">
<style>
body { font-family: Arial, sans-serif; background:#111; color:#eee; }
table { border-collapse: collapse; width: 420px; }
th, td { padding: 8px 12px; border: 1px solid #444; }
th { background:#222; }
.OK { color:#6ee36e; font-weight:bold; }
.WARNING { color:#ffd966; font-weight:bold; }
.CRITICAL { color:#ff6b6b; font-weight:bold; }
.meta { color:#aaa; font-size: 0.9em; }
</style>
</head>
<body>
$statusLine
<h2>Exchange Backup Health</h2>
<p>Overall Status: <strong class="$globalStatus">$globalStatus</strong></p>
<p class="meta">Last Updated: $nowString</p>

<table>
<tr><th>Server</th><th>Status</th></tr>
$($rows -join "`n")
</table>
</body>
</html>
"@

$folder = Split-Path $OutputPath
if (-not (Test-Path $folder)) {
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
}

$html | Out-File $OutputPath -Encoding UTF8

Write-Output "Backup health page written to $OutputPath with status $globalStatus"
