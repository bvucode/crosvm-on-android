### Network 1
Setup a persistent TAP interface
```
$ nvim network.sh
```
Set the value to the following
```
#!/data/data/com.termux/files/usr/bin/sh

# https://crosvm.dev/book/devices/net.html
ip tuntap add mode tap user $USER vnet_hdr crosvm_tap
ip addr add 192.168.10.1/24 dev crosvm_tap
ip link set crosvm_tap up

# routing
sysctl net.ipv4.ip_forward=1
HOST_DEV=$(ip route get 8.8.8.8 | awk -- '{printf $5}')
iptables -t nat -A POSTROUTING -o "${HOST_DEV}" -j MASQUERADE
iptables -A FORWARD -i "${HOST_DEV}" -o crosvm_tap -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i crosvm_tap -o "${HOST_DEV}" -j ACCEPT

# the main route table needs to be added
ip rule add from all lookup main pref 1
```
Copy file network.sh to the phone in /data/data/com.termux/files/home/kvm

In termux:
```
# su
# cd /data/data/com.termux/files/home/kvm
# chmod +x network.sh
# ./network.sh
```

```
# cd gvisor-tap-vsock-android/bin
# su
# chmod +x gvproxy
# ./gvproxy -debug -listen vsock://:1024 -listen unix:///data/data/com.termux/files/home/kvm/network.sock
```

In the guest
```
$ cd /gvisor-tap-vsock/bin
$ sudo chmod +x gvforwarder
$ sudo ./gvforwarder --debug &
or
$ sudo ./gvforwarder --debug > /dev/null 2>&1 &
$ ping 8.8.8.8
```
SSH
```
$ nvim network.sh
```
Set the value to the following
```
#!/bin/bash

# Replace with the actual network interface name of the guest
# (use "ip addr" to list the interfaces)
GUEST_DEV=enp0s5
sudo ip addr add 192.168.10.2/24 dev "${GUEST_DEV}"
sudo ip link set "${GUEST_DEV}" up
sudo ip route add default via 192.168.10.1
# "8.8.8.8" is chosen arbitrarily as a default, please replace with your local (or preferred global)
# DNS provider, which should be visible in `/etc/resolv.conf` on the host.
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

```
$ sudo chmod +x network.sh
$ sudo ./network.sh
```
In termux
```
ssh <username>@192.168.10.2
```

### Network 2

Official method networking from Crosvm docs modified for android

[Netplan](https://github.com/bvucode/crosvm-on-android/blob/master/start-vm-net.sh)

SSH
```
ssh <username>@192.168.8.2
```

### Network 3

Install Linux Kernel Modules after build the kernel
```
$ cp -r linux-x.x.xx ./rootfs
$ chroot ./rootfs /bin/bash
$ apt install build-essential
$ cd /linux-x.x.xx
$ make install
$ cd /
$ apt remove build-essential
$ rm -rf /linux-x.x.xx
$ exit
```
Or

Download modules and Image from Releases

Download curl-aarch64 from https://github.com/moparisthebest/static-curl and place it into the kvm directory.
```
$ cd /kvm
$ sudo chmod +x curl-aarch64
$ sudo nvim start-network.sh
```
Set the value to the following
```
#!/data/data/com.termux/files/usr/bin/sh

/data/data/com.termux/files/home/kvm/gvisor-tap-vsock-android/bin/gvproxy -listen vsock://:1024 -listen unix:///data/data/com.termux/files/home/kvm/network.sock &
sleep 1
./curl-aarch64 --unix-socket /data/data/com.termux/files/home/kvm/network.sock http:/unix/services/forwarder/expose -X POST -d '{"local":":22","remote":"192.168.127.2:22"}'
```
```
$ sudo chmod +x ./start-network.sh
$ sudo nvim ./start-vm.sh
```
Set the value to the following
```
#!/data/data/com.termux/files/usr/bin/sh

/apex/com.android.virt/bin/crosvm run --disable-sandbox --net tap-name=crosvm_tap -s /data/data/com.termux/files/home/kvm/crosvm.sock --shared-dir "/data/data/com.termux/files/home/host_shared_dir:my_shared_tag:type=fs" -p 'init=/sbin/init' --rwroot /data/data/com.termux/files/home/kvm/debian.img /data/data/com.termux/files/home/kvm/Image --vsock 3 --mem 2048 --cpus 8
```
```
$ sudo chmod +x ./start-vm.sh
```
In termux

```
# su
# cd /kvm
# ./start-network.sh
```
In a new session termux
```
# su
# cd /kvm
# ./start-vm.sh
```
SSH into the Phone

Grab the IP Address of the phone from its setting page or in terminal Ip r

On your technician machine(PC, Phone with Termux)
```
ssh <username>@<phone IP>
```
