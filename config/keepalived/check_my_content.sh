#!/bin/bash
#######################################################
# Contact john.wang@chinanetcloud.com
# Jun 26, 2009  JW      Initial create
# Jun 29, 2009  JW      Add comments
# Jun 3 , 2010  DL      Fix timeout ,add content check
# May 5 , 2014  MD      add break in for function
#######################################################
 
# Define node ip ,my haporxy ip, and check content
NODES=("10.9.1.205" "10.9.1.209")
MY_IP="118.102.28.107"
CHECK_URI="check.php"
CHECK_HOST="wotime.net"
CONTENT_VERIFY="OK"
 
# Check backend servers, exit 1 if all servers are unreachable
NODE_STATUS=1
for N in ${NODES1[*]};do
    if wget --header="Host: $CHECK_HOST" -q -t 2 --timeout=2 "http://$N/$CHECK_URI" -O - | grep "$CONTENT_VERIFY"; then
        NODE_STATUS=0
        break
    fi
done

if [ "$NODE_STATUS" -ne 0 ]; then
    logger "all backend servers are unreachable"    
    exit 1
fi
 
# Check if Perlbal active, exit 1 if not
HAPROXY_STATUS=1
if wget -q -t 2 --header="Host: $CHECK_HOST" --timeout=2 "http://$MY_IP/$CHECK_URI" -O - | grep "$CONTENT_VERIFY"; then
    HAPROXY_STATUS=0
fi
 
if [ "$HAPROXY_STATUS" -ne 0 ] ; then
    exit 1
else
    exit 0
fi

