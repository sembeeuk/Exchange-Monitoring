# diskhealth-public.ps1

$Servers = @("SERVER-1","SERVER-2","SERVER-3")
$OutputPath = "C:\inetpub\wwwroot\monitoring\diskhealth.htm"

$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$globalStatus = "OK"
$rows = @()

foreach ($server in $Servers) {

    $serverStatus = "OK"

    try {
        $drives = Get-WmiObject Win32_LogicalDisk -ComputerName $server -Filter "DriveType=3"
    }
    catch {
        $serverStatus = "CRITICAL"
    }

    if ($serverStatus -ne "CRITICAL") {
        foreach ($d in $drives) {
            if ($null -eq $d.Size -or $d.Size -eq 0) { continue }

            $freePercent = [math]::Round(($d.FreeSpace / $d.Size) * 100, 1)
            $label = if ([string]::IsNullOrWhiteSpace($d.VolumeName)) { "NoLabel" } else { $d.VolumeName }

            $warn = 20
            $crit = 15

            switch -Wildcard ($label.ToUpper()) {
                "*OS*"    { $warn = 20; $crit = 15 }
                "*DB*"    { $warn = 25; $crit = 20 }
                "*LOG*"   { $warn = 30; $crit = 20 }
                "*QUEUE*" { $warn = 25; $crit = 15 }
            }

            if ($freePercent -lt $crit) {
                $serverStatus = "CRITICAL"
                break
            }
            elseif ($freePercent -lt $warn -and $serverStatus -ne "CRITICAL") {
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

$statusLine = "<!-- EXCHANGE-DISK-STATUS: $globalStatus -->"

$html = @"
<!doctype html>
<html>
<head>
<title>Exchange Health</title>
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
<h2>Exchange Health</h2>
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

Write-Output "Public Exchange health page written to $OutputPath with status $globalStatus"
