# queuehealth-public.ps1

$Servers = @("SERVER-1","SERVER-2","SERVER-3")
$OutputPath = "C:\inetpub\wwwroot\monitoring\queuehealth.htm"

# Tune these
$TotalQueueWarn = 10
$TotalQueueCrit = 50
$SingleQueueWarn = 5
$SingleQueueCrit = 20

$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$globalStatus = "OK"
$rows = @()

# Load Exchange snap-in if needed
try {
    if (-not (Get-Command Get-Queue -ErrorAction SilentlyContinue)) {
        Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction Stop
    }
}
catch {
    $globalStatus = "CRITICAL"
}

foreach ($server in $Servers) {

    $serverStatus = "OK"

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
            $serverStatus = "CRITICAL"
        }
        elseif ($totalMessages -ge $TotalQueueWarn -or $maxSingleQueue -ge $SingleQueueWarn) {
            $serverStatus = "WARNING"
        }
    }
    catch {
        $serverStatus = "CRITICAL"
    }

    if ($serverStatus -eq "CRITICAL") {
        $globalStatus = "CRITICAL"
    }
    elseif ($serverStatus -eq "WARNING" -and $globalStatus -ne "CRITICAL") {
        $globalStatus = "WARNING"
    }

    $rows += "<tr><td>$server</td><td class='$serverStatus'>$serverStatus</td></tr>"
}

$statusLine = "<!-- EXCHANGE-QUEUE-STATUS: $globalStatus -->"

$html = @"
<!doctype html>
<html>
<head>
<title>Exchange Queue Health</title>
<meta http-equiv="refresh" content="60">
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
<h2>Exchange Queue Health</h2>
<p>Overall Status: <strong class="$globalStatus">$globalStatus</strong></p>
<p class="meta">Last Updated: $now</p>

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

Write-Output "Public Exchange queue health page written to $OutputPath with status $globalStatus"
