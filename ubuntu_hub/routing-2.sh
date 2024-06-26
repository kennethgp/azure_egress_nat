#!/bin/bash

# enable ip forwarding
sudo sed -i 's/#net\.ipv4\.ip_forward=1/net\.ipv4\.ip_forward=1/g' /etc/sysctl.conf

# enable the routing
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# install software to save iptables on reboot
sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
sudo iptables-save | sudo tee -a /etc/iptables/rules.v4

# add the routes (eth1 = private, eth0 = internet)
sudo ip route add 10.0.0.0/8 via 10.0.1.1 dev eth1 && \
sudo ip route add 168.63.129.16 via 10.0.1.1 dev eth1 proto dhcp src 10.0.1.6

# force iptables and routing on boot
echo '#!/bin/bash
/sbin/iptables-restore < /etc/iptables/rules.v4
sudo ip route add 10.0.0.0/8 via 10.0.1.1 dev eth1
sudo ip route add 168.63.129.16 via 10.0.1.1 dev eth1 proto dhcp src 10.0.1.6
' | sudo tee -a /etc/rc.local && sudo chmod +x /etc/rc.local

sudo reboot