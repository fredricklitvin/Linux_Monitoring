#!/bin/bash

source .env
mkdir -p /monitore/logs
LOG_FILE=/monitore/logs/monitor_$(date '+%Y-%m-%d_%H-%M-%S').log
exec &> >(tee -a $LOG_FILE)

alert=0

CPU_USAGE=$(mpstat 1 1 | awk '/all/ {usage = 100 - $NF} END {print usage}')
echo "CPU usage: " $CPU_USAGE"%" 
echo ""

MEMORY_FREE=$(free  -h | awk  ' /Mem:/ {print $3 "/" $2}')
echo "Memory used: $MEMORY_FREE"
echo ""

DISK_FREE=$(df -h / | awk 'NR==2 {print "Disk free:", $4, "Usage:", $5}')
echo $DISK_FREE
echo ""

echo "Top proccess by cpu:"
CPU_PROCESS="$(ps -eo user,uid,comm,pid,pmem,pcpu --sort=-pcpu | head -n 6)"
printf '%s\n' "$CPU_PROCESS" 
echo ""

echo "Top proccess by mem:"
MEMORY_PROCESS="$(ps -eo user,uid,comm,pid,pcpu,pmem --sort=-pmem | head -n 6)"
printf '%s\n' "$MEMORY_PROCESS" 
echo ""

echo "Docker logs:"
for dockername in $(docker ps  --format '{{.Names}}'); do 
	echo $dockername 
	dockerlogs=$(docker logs $dockername --tail 20)
	printf "%s\n" "$dockerlogs" 
	echo ""
	if echo "$dockerlogs" | grep -iq "error" ;then echo "Docker container '$dockername' shows errors in logs." 
		DOCKER_FAILED+="-$dockername\n"
		echo ""
	fi ;done


echo "Stopped Docker logs:"
for dockername in $(docker ps -a --filter 'status=exited'  --format '{{.Names}}'); do
        echo $dockername
	dockerlogs=$(docker logs $dockername --tail 20)
	printf "%s\n" "$dockerlogs" 
       	echo ""
	if  echo "$dockerlogs" | grep -iq "error" ; then echo "Docker container '$dockername' shows errors in logs." 
		DOCKER_FAILED+="-$dockername\n"       
		echo "" 
        fi ;done 

echo ""

echo "DNS check:"
read -ra dns_list <<< "$DNS_LIST"
for t in ${dns_list[@]}; do 
	echo "----------$t----------"
if [[ -z $(dig +short $t) ]]; then echo "DNS RECORD $t FAILED"  
	DNS_FAILED+="-$t\n"
	echo ""
else dig $t
echo ""
	fi ;done 

echo ""

echo "Nginx check:"
nginx -t && echo ""

echo "System services check:"
read -ra service_list <<< "$SERVICE_LIST"
for s in ${service_list[@]};do
	echo "----------$s----------"
	if [[ $(systemctl is-active "$s") != "active" ]]; then
		echo "Service $s is not active"
		echo ""
		FAILED_SERVICES+="-$s\n"
	else
		echo "Service $s is running"
		echo ""
	fi done


echo "ISSUES:"
if [[ $(echo "$CPU_USAGE >= $CPU_USAGE_THRESHOLD" | bc -l) -eq 1 ]];then 
	echo "High CPU usage: $CPU_USAGE"
	alert=1
	echo ""
fi

MEMORY_CHECK=$(free -h | awk '/Mem:/ {gsub("Gi","",$3); gsub("Gi","",$2); print $3 "/" $2}')
USED_MEMORY=$(echo $MEMORY_CHECK | awk -F '/' '{print$1}')
TOTAL_MEMORY=$(echo $MEMORY_CHECK | awk -F '/' '{print$NF}')
PRECENT_USED=$(echo "scale=3; $USED_MEMORY / $TOTAL_MEMORY * 100" | bc -l)
if [[ $(echo "$PRECENT_USED >= $MEMORY_USAGE_THRESHOLD" | bc -l) -eq 1 ]];then 
	echo "High Memory usage: $PRECENT_USED%"
	alert=1
	echo ""
fi

DISK_CHECK=$(echo $DISK_FREE | awk '{gsub("%","",$NF); print$NF}')
if [[ $(echo "$DISK_CHECK >= $DISK_USAGE_THRESHOLD" | bc -l) -eq 1 ]];then 
	echo "Low disk space $DISK_CHECK% used"
	alert=1
	echo ""
fi


for (( i=2; i<=$(printf '%s\n' "$CPU_PROCESS" | wc -l); i++));do
	if [[ $(echo "$(printf '%s\n' "$CPU_PROCESS" | awk "NR == $i {print \$NF}") >= $CPU_PROC_THRESHOLD" |bc -l) -eq 1 ]]; then
		HIGH_CPU_PROCESS+="-$(printf '%s\n' "$CPU_PROCESS" | awk "NR == $i {print \$3,\$NF}")%\n"
	fi
done
if [[ -n $HIGH_CPU_PROCESS ]] ; then
	printf "These Processes take too much CPU:\n%b" "$HIGH_CPU_PROCESS"
	alert=1
fi
echo ""

for (( i=2; i<=$(printf '%s\n' "$MEMORY_PROCESS" | wc -l); i++));do
        if [[ $(echo "$(printf '%s\n' "$MEMORY_PROCESS" | awk "NR == $i {print \$NF}") >= $MEM_PROC_THRESHOLD" |bc -l) -eq 1 ]]; then
        	HIGH_MEMORY_PROCESS+="-$(printf '%s\n' "$MEMORY_PROCESS" | awk "NR == $i {print \$3,\$NF}")%\n"
	fi
done
if [[ -n $HIGH_MEMORY_PROCESS ]] ; then
        printf "These Processes take too much CPU:\n%b" "$HIGH_MEMORY_PROCESS"
	alert=1
fi
echo ""


if [[ -n $DNS_FAILED ]]; then 
	printf "Failed DNS:\n%b" "$DNS_FAILED"
	alert=1
	echo ""
fi

if [[ -n $DOCKER_FAILED ]]; then
	printf  "Failed dockers:\n%b" "$DOCKER_FAILED"
	alert=1
	echo ""
fi

if [[ -n $FAILED_SERVICES ]]; then
	printf  "Failed services:\n%b" "$FAILED_SERVICES"
	alert=1
	echo ""
fi


if [[ $alert -eq 1 ]]; then
	TO=$TEST_MAIL
	BODY=$(cat $LOG_FILE)
	
	echo -e "To: $TO\nSubject: alerting from $(hostname)\n\n$BODY" | ssmtp $TO
	
	exit 1

else
	exit 0

fi
	
