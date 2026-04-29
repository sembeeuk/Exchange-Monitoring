mkdir c:\InetPub\wwwroot\monitoring
schtasks /create /tn "Exchange Disk Health" /tr "powershell.exe -ExecutionPolicy Bypass -File C:\Scripts\diskhealth-public.ps1" /sc minute /mo 5 /ru SYSTEM /rl HIGHEST /f
schtasks /create /tn "Exchange Queue Health" /tr "powershell.exe -ExecutionPolicy Bypass -File C:\Scripts\queuehealth-public.ps1" /sc minute /mo 5 /ru SYSTEM /rl HIGHEST /f
schtasks /create /tn "Exchange Backup Health" /tr "powershell.exe -ExecutionPolicy Bypass -File C:\Scripts\backuphealth-public.ps1" /sc minute /mo 5 /ru SYSTEM /rl HIGHEST /f
