# Exchange Monitoring (External / Agentless)

These scripts provide a simple way to monitor Exchange servers from outside the network, where installing traditional monitoring agents is not possible or not allowed.

They generate lightweight HTML status pages which can be checked by external monitoring tools such as Uptime Kuma.

The output is intentionally minimal and only exposes:
- Server name
- Overall status (OK / WARNING / CRITICAL)

No sensitive information (disk layout, sizes, queue detail, etc.) is exposed.

---

## What this covers

- Disk pressure (primary cause of Exchange back pressure issues)
- Transport queue health
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
   $Servers = @("EX1-2016","EX2-2016","EX3-2016")

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

https://yourdomain/monitoring/diskhealth.htm  
https://yourdomain/monitoring/queuehealth.htm  

Use the keyword:

<strong class="OK">OK</strong>

Configure Kuma to alert when the keyword is missing.

### Behaviour

OK        -> Pass  
WARNING   -> Alert  
CRITICAL  -> Alert  
No update -> Alert  

---

## Exchange Healthcheck URLs

These can be monitored alongside the scripts for service availability and SSL validation:

Outlook Anywhere (RPC over HTTP):  
/rpc/healthcheck.htm  

MAPI/HTTP:  
/mapi/healthcheck.htm  

Outlook Web App (OWA):  
/owa/healthcheck.htm  

Exchange Control Panel (ECP):  
/ecp/healthcheck.htm  

Exchange ActiveSync:  
/Microsoft-Server-ActiveSync/healthcheck.htm  

Exchange Web Services (EWS):  
/ews/healthcheck.htm  

Offline Address Book (OAB):  
/oab/healthcheck.htm  

Autodiscover:  
/Autodiscover/healthcheck.htm  

---

## Notes

- Designed for environments where:
  - Agents are not allowed
  - Legacy OS (e.g. Server 2012 R2) causes TLS/API issues
- Works well with load-balanced Exchange environments
- Simple by design — prioritises reliability and low noise over complexity

---

## Summary

This is not a full monitoring solution.

It is a practical, low-impact way to detect when Exchange is under pressure before users notice.
