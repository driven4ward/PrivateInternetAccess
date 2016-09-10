#!/bin/bash
if [[ $UID != 0 ]]; then
    echo "This must be run as root."
    exit 1
fi

HOST=$1
LOCATION=$2
VPN_NETWORK="vpn-${LOCATION// /_}"
NETWORK=$(grep "$LOCATION" /etc/openvpn/pia/vpn-networks | cut -d':' -f2)

if [ -z "$NETWORK" ] || ! ip netns list | grep -qw "$VPN_NETWORK" ; then
    echo "Error: Could not find location: '$LOCATION'"
    exit 1
fi

DATE=`date`
PING_RES="ip netns exec $VPN_NETWORK ping -c 5 -i 10 $HOST"
PLOSS=$($PING_RES | grep -oP '\d+(?=% packet loss)')  
echo "$DATE : Loss Result : $PLOSS"
 
if [ "100" -eq "$PLOSS" ] ; then
    echo "Restarting vpn@$LOCATION ..."
    systemctl restart "vpn@$LOCATION"
fi
