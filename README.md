# Exchange-Monitoring

These are a couple of scripts that I use to monitor Exchange servers from outside the network, where I cannot install usual monitoring tools. 
They can then be used with UptimeKuma to alert me that there is a problem, which I can then remote on to the server and check. They do not expose anything other than the server name and status. 

To Use

1. In C:\InetPub\wwwroot create a folder called Monitoring.
2. Create a directory to hold the scripts - I use C:\Scripts. If you use something else, then adjust the scheduled task.
3. Copy the scripts and adjust the line that lists the servers.
4. Create the two scheduled tasks.

If you have more than one server in a load balancer pool, then copy the scripts and create the scheduled task on each server. That way it doesn't matter which one is public.

Uptime Kuma

In UptimeKuma, create a HTTPS keyword monitor, looking for "<strong class="OK">OK</strong>" - if a drive or queue is not OK, then the monitor will fail. 

Combine them with the healthcheck URLs:

Outlook Anywhere (aka RPC over HTTP): /rpc/healthcheck.htm
MAPI/HTTP: /mapi/healthcheck.htm
Outlook Web App (aka Outlook on the web): /owa/healthcheck.htm
Exchange Control Panel: /ecp/healthcheck.htm
Exchange ActiveSync: /Microsoft-Server-ActiveSync/healthcheck.htm
Exchange Web Services: /ews/healthcheck.htm
Offline Address Book: /oab/healthcheck.htm
AutoDiscover: /Autodiscover/healthcheck.htm
