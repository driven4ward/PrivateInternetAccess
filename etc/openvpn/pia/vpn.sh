#!/bin/bash
if [[ $UID != 0 ]]; then
    echo "This must be run as root."
    exit 1
fi

function ip2int() {
    local a b c d
    { IFS=. read a b c d; } <<< $1
    echo $(((((((a << 8) | b) << 8) | c) << 8) | d))
}

function int2ip() {
    local ui32=$1; shift
    local ip n
    for n in 1 2 3 4; do
        ip=$((ui32 & 0xff))${ip:+.}$ip
        ui32=$((ui32 >> 8))
    done
    echo $ip
}

function netmask() {
    local mask=$((0xffffffff << (32 - $1))); shift
    int2ip $mask
}

function broadcast() {
    local addr=$(ip2int $1); shift
    local mask=$((0xffffffff << (32 -$1))); shift
    int2ip $((addr | ~mask))
}

function network() {
    local addr=$(ip2int $1); shift
    local mask=$((0xffffffff << (32 -$1))); shift
    int2ip $((addr & mask))
}

OPERATION=$1
LOCATION=$2
NETWORK=$(grep "$LOCATION" /etc/openvpn/pia/vpn-networks | cut -d':' -f2)
VPN_NETWORK="vpn-${LOCATION// /_}"
IP1=$(int2ip $(($(ip2int $NETWORK)+1)))
IP2=$(int2ip $(($(ip2int $NETWORK)+2)))
VETH0=$(($(echo $NETWORK | cut -d'.' -f3)*2))
VETH1=$((VETH0+1))

if [ -z "$NETWORK" ]; then
    echo "Error: Could not find location: '$LOCATION'"
    exit 1
fi

function vpn_up() {

    if [ ! -f "/var/run/netns/$VPN_NETWORK" ]; then
        sysctl -q net.ipv4.ip_forward=1
        ip netns add "$VPN_NETWORK"
        ip netns exec "$VPN_NETWORK" ip link set dev lo up
        ip link add "vpn$VETH0" type veth peer name "vpn$VETH1"
        ip link set "vpn$VETH1" netns "$VPN_NETWORK"

        ifconfig "vpn$VETH0" "$IP1"/24 up
        ip netns exec "$VPN_NETWORK" ifconfig "vpn$VETH1" "$IP2"/24 up
        ip netns exec "$VPN_NETWORK" ip route add default via "$IP1" dev "vpn$VETH1"

        mkdir -p /etc/netns/"$VPN_NETWORK"
        echo 'nameserver 209.222.18.222
nameserver 209.222.18.218' > "/etc/netns/$VPN_NETWORK/resolv.conf"

        ip netns exec "$VPN_NETWORK" openvpn --config "/etc/openvpn/pia/$LOCATION.ovpn" &
        while ! ip netns exec "$VPN_NETWORK" ip a show dev tun0 up; do
            sleep .5
        done
    fi

}

function vpn_down() {

    if [ -f "/var/run/netns/$VPN_NETWORK" ]; then
        ip netns exec "$VPN_NETWORK" killall -9 "/etc/openvpn/pia/$LOCATION.ovpn" 2>/dev/null
        ip link delete "vpn$VETH0" 2>/dev/null
        ip netns delete "$VPN_NETWORK" 2>/dev/null
        rm -rf "/etc/netns/$VPN_NETWORK" 2>/dev/null
    fi

}

case "$OPERATION" in
    up)
        vpn_up ;;
    down)
        vpn_down ;;
    *)
        echo "Syntax: $0 up|down <location>"
        exit 1
        ;;
esac
