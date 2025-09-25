#!/data/data/com.termux/files/usr/bin/sh

# Edit /etc/netplan/90-default.yaml in the VM like this:
# ""
# network:
#    version: 2
#    ethernets:
#        all-en:
#            match:
#                name: en*
#            dhcp4: false
#
#            addresses:
#              - 192.168.8.2/24
#            routes:
#              - to: default
#                via: 192.168.8.1
#            nameservers:
#                  addresses: [8.8.8.8]
#            dhcp6: true
#            dhcp6-overrides:
#                use-domains: true
#        all-eth:
#            match:
#                name: eth*
#            dhcp4: true
#            dhcp4-overrides:
#                use-domains: true
#            dhcp6: true
#            dhcp6-overrides:
#                use-domains: true
# ""
# netplan apply
# ping www.google.com

ifname=crosvm_tap
if [ ! -d /sys/class/net/$ifname ]; then
    ip tuntap add mode tap vnet_hdr $ifname
    ip addr add 192.168.8.1/24 dev $ifname
    ip link set $ifname up
    ip r a table wlan0 192.168.8.0/24 via 192.168.8.1 dev $ifname
    iptables -D INPUT -j ACCEPT -i $ifname
    iptables -D OUTPUT -j ACCEPT -o $ifname
    iptables -I INPUT -j ACCEPT -i $ifname
    iptables -I OUTPUT -j ACCEPT -o $ifname
    iptables -t nat -D POSTROUTING -j MASQUERADE -o wlan0 -s 192.168.8.0/24
    iptables -t nat -I POSTROUTING -j MASQUERADE -o wlan0 -s 192.168.8.0/24
    sysctl -w net.ipv4.ip_forward=1
    
    ip rule add from all fwmark 0/0x1ffff iif wlan0 lookup wlan0
    ip rule add iif $ifname lookup wlan0
    
    iptables -j ACCEPT -D FORWARD -i $ifname -o wlan0
    iptables -j ACCEPT -D FORWARD -m state --state ESTABLISHED,RELATED -i wlan0 -o $ifname
    iptables -j ACCEPT -D FORWARD -m state --state ESTABLISHED,RELATED -o wlan0 -i $ifname
    iptables -j ACCEPT -I FORWARD -i $ifname -o wlan0
    iptables -j ACCEPT -I FORWARD -m state --state ESTABLISHED,RELATED -i wlan0 -o $ifname
    iptables -j ACCEPT -I FORWARD -m state --state ESTABLISHED,RELATED -o wlan0 -i $ifname
fi

/apex/com.android.virt/bin/crosvm run --disable-sandbox  --net tap-name=$ifname -s /data/data/com.termux/files/home/kvm/crosvm.sock --shared-dir "/data/data/com.termux/files/home/host_shared_dir:my_shared_tag:type=fs" -p 'init=/sbin/init' --rwroot /data/data/com.termux/files/home/kvm/debian.img /data/data/com.termux/files/home/kvm/Image --vsock 3 --mem 2048 --cpus 8
