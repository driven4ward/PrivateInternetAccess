#!/bin/bash
if [[ $UID != 0 ]]; then
    echo "This must be run as root."
    exit 1
fi

INSTALL_DIR="/etc/openvpn/pia"
SERVICE_DIR="/usr/lib/systemd/system"
PIA_SOURCE="https://www.privateinternetaccess.com/openvpn/openvpn.zip"
PIA_SOURCE_HASH="f6d7d14f458f9d8d4dfb05b454d495ed"
VPN_SUBNET="10.100.X.0"

function vpn_install_openvpn() {
    pacman -S openvpn --noconfirm 2>/dev/null
}

function vpn_fetch_config() {
    mkdir -p "$INSTALL_DIR"
    rm -rf "$INSTALL_DIR"/*.{zip,crt,pem,ovpn}
    wget -O "$INSTALL_DIR"/openvpn.zip "$PIA_SOURCE"
    if ! md5sum -c <<<"$PIA_SOURCE_HASH $INSTALL_DIR"/openvpn.zip ; then
        exit 1
    else
        unzip -o "$INSTALL_DIR"/openvpn.zip -d "$INSTALL_DIR" > /dev/null
        chown root.root "$INSTALL_DIR"/*.{crt,pem,ovpn}
        chmod 644       "$INSTALL_DIR"/*.{crt,pem,ovpn}
    fi
    rm -rf "$INSTALL_DIR"/openvpn.zip
}

function vpn_fix_files() {
    for file in "$INSTALL_DIR"/*.ovpn
    do
        sed -i "s#crl-verify crl.rsa.2048.pem#crl-verify $INSTALL_DIR/crl.rsa.2048.pem#g" "$file"
        sed -i "s#ca ca.rsa.2048.crt#ca $INSTALL_DIR/ca.rsa.2048.crt#g" "$file"
        if ! grep -q passwd "$file"; then
            echo "
# Add these lines:
auth-user-pass  $INSTALL_DIR/passwd
keepalive       60 600
" >> "$file"
        fi
    done
}

function vpn_create_map() {
    COUNTER=1
    rm -rf "$INSTALL_DIR"/vpn-networks
    for file in "$INSTALL_DIR"/*.ovpn
    do
        echo "${file:17:-5}:$(echo $VPN_SUBNET | sed -e "s#.X.#.$COUNTER.#g")" >> "$INSTALL_DIR"/vpn-networks
        let COUNTER=COUNTER+1
    done
        chown root.root "$INSTALL_DIR"/vpn-networks
        chmod 644       "$INSTALL_DIR"/vpn-networks
}

function vpn_setup_firewall() {
    firewall-cmd --permanent --zone=home     --add-masquerade     2>/dev/null
    firewall-cmd --permanent --zone=external --add-masquerade     2>/dev/null
    firewall-cmd --permanent --zone=external --add-interface=vpn+ 2>/dev/null
    firewall-cmd --reload                                         2>/dev/null
}

function vpn_copy_scripts() {
    cp -f ./"$INSTALL_DIR"/vpn{,-ping}.sh "$INSTALL_DIR"
    chown root.root "$INSTALL_DIR"/*.sh
    chmod 744       "$INSTALL_DIR"/*.sh
}

function vpn_copy_services() {
    cp -f ./"$SERVICE_DIR"/vpn*.* "$SERVICE_DIR"
    chown root.root "$SERVICE_DIR"/*.*
    chmod 644       "$SERVICE_DIR"/*.*
}

function vpn_setup_passwd() {
    echo -n VPN Username: 
    read -s vpn_username
    echo 
    echo -n VPN Password: 
    read -s vpn_password
    echo 
    echo "$vpn_username
$vpn_password
" > "$INSTALL_DIR"/passwd
    chown root.root "$INSTALL_DIR"/passwd
    chmod 600       "$INSTALL_DIR"/passwd
}

case "$1" in
    install-openvpn)
        shift; vpn_install_openvpn ;;  
    fetch-config)
        shift; vpn_fetch_config ;;    
    fix-files)
        shift; vpn_fix_files ;;
    create-map)
        shift; vpn_create_map ;;
    setup-firewall)
        shift; vpn_setup_firewall ;;  
    copy-scripts)
        shift; vpn_copy_scripts ;;
    copy-services)
        shift; vpn_copy_services ;;
    setup-passwd)
        shift; vpn_setup_passwd ;;  
    *)
        echo "Syntax: $0 install-openvpn|fetch-config|fix-files|create-map|setup-firewall|copy-scripts|copy-services|setup-passwd"
        exit 1
        ;;
esac
