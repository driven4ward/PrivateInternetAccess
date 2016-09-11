## PrivateInternetAccess

The scripts are built for [manjaro](https://www.manjaro.org "Manjaro Linux Homepage"), which is based on [arch](https://www.archlinux.org "Arch Linux Homepage").

### Usage
Syntax:
  * ./vpn-setup.sh install-openvpn|fetch-config|fix-files|create-map|setup-firewall|copy-scripts|copy-services|setup-passwd

### Setup  
Once the setup is completed, vpn connections to the various countries can be started via the command:  
  * systemctl enable -f vpn@`<Country>`.service && systemctl start vpn@`<Country>`.service  
  
A timer based ping service is also available, that will restart the vpn when the pings timeout.  
The service are to bound to the vpn connection started above, via the command:  
  * systemctl enable -f vpn-ping@`<Country>`.service && systemctl start vpn-ping@`<Country>`.service  


Other services can be made to use the VPN by using the setup shown below:  
[Unit]  
Description=Sample service that connects via VPN  
After=vpn@`<Country>`.service  
Requires=vpn@`<Country>`.service  
  
[Service]  
Type=simple  
User=root  
UMask=0007  
ExecStart=/usr/bin/ip netns exec vpn-`<Country>` sudo -H -u `<user>` -g `<group>` bash -c 'umask 002;traceroute 8.8.8.8'  
  
[Install]  
WantedBy=multi-user.target  
