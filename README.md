# nap-dos-demo

## Introduction
At the time of this writing, NGINX App Protect DoS (NAP DoS) is still in beta version. You may sign up for free trial at https://f5beta.centercode.com/welcome/, you will receive instructions to download the binaries and set it up.

The purpose of this repo is to provide an easy setup for learning and demonstrating NAP DoS.

I have cloned the NAP DoS dashboard from https://github.com/f5devcentral/nap-dos-elk-dashboards into this repo for ease of setup.

## Setup
0. Build NAP DoS Docker image</br>
Follow the instruction in the beta program to build a local docker container app-protect-dos image.

1. Clone the repo
```
git clone https://github.com/mcheo-nginx/nap-dos-demo.git
cd nap-dos-demo
```

2. Step up the stacks
```
docker-compose -f docker-compose.yaml up -d
```
The stack consists of 5 containers:

- NGINX App Protect DoS instance
- Juice Shop as backend app server
- Legitimate container to generate good traffic
- Attacker container to generate attack traffic
- Elasticsearch for NAP DoS dashboard


3. Complete Elasticsearch setup</br>
Use browser to visit http://localhost:5601, once the page loads successfully which means startup has completed, execute the following steps:

```
Step 3.1
curl -X PUT "localhost:9200/_cluster/settings?pretty" -H 'Content-Type: application/json' -d'
{
  "transient": {
    "cluster.routing.allocation.disk.threshold_enabled": "false"
  }
}'

Step 3.2
curl -X PUT "localhost:9200/_all/_settings?pretty" -H 'Content-Type: application/json' -d'
{
	"index.blocks.read_only_allow_delete": null
}
'

Step 3.3
cd elk

curl -XPUT "http://localhost:9200/app-protect-dos-logs"  -H "Content-Type: application/json" -d  @apdos_mapping.json

curl -XPOST "http://localhost:9200/app-protect-dos-logs/_mapping"  -H "Content-Type: application/json" -d  @apdos_geo_mapping.json

Step 3.4
KIBANA_CONTAINER_URL=http://localhost:5601

jq -s . kibana/apdos-dashboard.ndjson | jq '{"objects": . }' | \
curl -k --location --request POST "$KIBANA_CONTAINER_URL/api/kibana/dashboards/import" \
    --header 'kbn-xsrf: true' \
    --header 'Content-Type: text/plain' -d @- \
    | jq

```

4. Enable NAP DoS logging</br>
Edit nginx/nginx.conf file and uncomment the following 2 lines:
```
#app_protect_dos_security_log "/etc/app_protect_dos/log-default.json" syslog:server=elasticsearch:5261;

#access_log syslog:server=elasticsearch:5561 log_dos if=$loggable;
```
Execute NGINX reload
```
docker exec -it nap-dos-demo_nginx_1 nginx -s reload
```

You may browse the Juice Shop application at http://localhost

5. Generate baseline traffic
```
docker exec -it nap-dos-demo_legitimate_1 /bin/bash
cd /home
chmod 755 good.sh
./good.sh
```
For a start, let it runs for at least 8-10 minutes. Let NAP DoS does its initial baselining. If everything is working as expected, Elasticsearch AP_DOS: AppProtectDOS dashboard should display charts.

You may visit the Elasticsearch dashboard at http://localhost:5601 </br>
Default dashboard has filter, apply or remove filter as you wish.

6. Generate attack traffic</br>
While the good traffic still running at the background, you may start the attack traffic
```
docker exec -it nap-dos-demo_attacker_1 /bin/bash
cd /home
chmod 755 bad.sh
./bad.sh
```


## Interpret the Graph

<img src="elk/images/dashboard1.png" width="800px"/>

The general idea is NAP DoS leverage on its ML to perform behaviour dos mitigation. No manual (human) tuning, re-tuning required.

- When the attack happens, a sharp increase of traffic in "AP_DOS: Client HTTP transaction/s" panel and "AP_DOS: Server HTTP transactions/s"
- NGINX detects server stress, spike in "AP_DOS: Server_stress_level" panel
- Initially, NGINX will goes into self defense mode by doing global challenge. Red patch (Redirect/Challenge global RPS) shows in "AP_DoS: HTTP Mitigation" panel
- Once NAP DoS gather sufficient data and generate dynamic attack signatures in response to this particular attack, attack signature shows in "AP_DoS: Attack Signatures" panel, purple patch (Redirect/Challenge signatures RPS) shows in "AP_DOS: HTTP Mitigation" panel. At thsi time NAP DoS is doing targeted mitigation instead of global mitigation.</br>
**Note**: This dynamic attack signature is crafted for this specific attack, highly accurate and reduce false positive. If attacker re-tool and tweak its attack, NAP DoS will auto regenerate a new dynamic signature for the new attack.
- If the attack prolongs and those source IP has been identified as bad actors in "AP_DOS: Detected bad actors" panel, yellow patch (Redirect/Challenge bad actors RPS) shows in "AP_DOS: HTTP Mitigation" panel
- Despite the attack traffic keeps coming in (high traffic in "AP_DOS: Client HTTP transaction/s" panel), NAP DoS has mitigate and send only legitimate traffic to backend server (lower traffic in "AP_DOS: Server HTTP transactions/s" panel). As a good user, you may visit the page in http://localhost and it is working fine.
- There is Start and End bell flag in the charts that signifiy start and end of attack.
