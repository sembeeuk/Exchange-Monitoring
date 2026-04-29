# Exchange Monitoring (External / Agentless)

These scripts provide a simple way to monitor Exchange servers from outside the network, where installing traditional monitoring agents is not possible or not allowed, or the agent status cannot be seen by the Exchange Server admin. 

They generate lightweight HTML status pages which can be checked by external monitoring tools such as Uptime Kuma.

The output is intentionally minimal and only exposes:
- Server name
- Overall status (OK / WARNING / CRITICAL)

No sensitive information (disk layout, sizes, queue detail, etc.) is exposed.

A further script creates a single dashboard which is ideal for an at a glance check. 

---

## What this covers

- Disk space (primary cause of Exchange back pressure issues)
- Transport queue health
- Backup Health Check
- Standard Exchange healthcheck URLs (for service availability + SSL)

This approach focuses on:

Early warning rather than just uptime monitoring

---

## Setup

1. Create a folder in IIS:
   C:\InetPub\wwwroot\monitoring

2. Create a folder for scripts (example):
   C:\Scripts

3. Copy the scripts into that folder.

4. Edit each script and update the server list:
   $Servers = @("SERVER-1","SERVER-2","SERVER-3")
   Also update any threshold settings to suit your own requirements. Remember to update the individual scripts and the dashboard script. 

5. Create scheduled tasks to run the scripts (e.g. every 5 minutes).

---

## Multiple Servers / Load Balancers

If Exchange is behind a load balancer:

- Deploy the scripts to each Exchange server
- Create the scheduled task on each server

This ensures the status page is always available regardless of which server is accessed externally.

---

## Uptime Kuma Configuration

Create an HTTP(s) Keyword Monitor against:

- https://mail.example.com/monitoring/diskhealth.htm  
- https://mail.example.com/monitoring/queuehealth.htm
- https://mail.example.com/monitoring/backuphealth.htm

Use the keyword:

`<strong class="OK">OK</strong>`

Configure Uptime Kuma to alert when the keyword is missing.

### Behaviour

OK        -> Pass  
WARNING   -> Alert  
CRITICAL  -> Alert  
No update -> Alert  

---

## Dashboard

The dashboard can be viewed at https://mail.example.com/monitoring/exchangehealth.htm

---

## Exchange Healthcheck URLs

These can be monitored alongside the scripts for service availability and SSL validation:

Outlook Anywhere (RPC over HTTP):  
https://mail.example.com/rpc/healthcheck.htm  

MAPI/HTTP:  
https://mail.example.com/mapi/healthcheck.htm  

Outlook Web App (OWA):  
https://mail.example.com/owa/healthcheck.htm  

Exchange Control Panel (ECP):  
https://mail.example.com/ecp/healthcheck.htm  

Exchange ActiveSync:  
https://mail.example.com/Microsoft-Server-ActiveSync/healthcheck.htm  

Exchange Web Services (EWS):  
https://mail.example.com/ews/healthcheck.htm  

Offline Address Book (OAB):  
https://mail.example.com/oab/healthcheck.htm  

Autodiscover:  
https://mail.example.com/Autodiscover/healthcheck.htm  

---

## Notes

- Name your drives - the scripts use the drive names to indicate where there is an issue. 

---

## Summary

This is not a full monitoring solution.

It is a practical, low-impact way to detect when Exchange is under pressure before users notice.
