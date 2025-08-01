# Run Linux on Android without AVF support

### Good to Mention

* The device used here is a Xiaomi Poco C65 phone running Android 15
* Unlock bootloader
* You need a [rooted](https://en.m.wikipedia.org/wiki/Rooting_(Android)) device
* If you damage your device in any way, you are all responsible for it!

### Install dependencies
```
$ sudo apt install build-essential debootstrap qemu-user-static gcc-aarch64-linux-gnu atftpd nfs-kernel-server fdisk libcap-dev libgbm-dev pkg-config protobuf-compiler bc bison flex libssl-dev make libc6-dev libncurses5-dev crossbuild-essential-arm64

$ rm -rf /usr/local/go && tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
```

Add this to your ~/.bashrc

export PATH=$PATH:/usr/local/go/bin

### Build the kernel

Grab a kernel tarball from kernel.org.
```
$ tar -xvf linux-x.x.xx.tar.xz
$ cd linux-x.x.xx
$ make ARCH=arm64 defconfig
```
[enable from this config](https://github.com/bvucode/Crosvm-on-android/blob/main/common.config)

```
$ make menuconfig
$ CROSS_COMPILE=aarch64-linux-gnu- make ARCH=arm64 -j 8
```
### Cross-compile gVisor Proxy for aarch64

git clone https://github.com/containers/gvisor-tap-vsock gvisor-tap-vsock-arm64

GOARCH=arm64 make

### Cross-compile gVisor Proxy for Android

git clone https://github.com/containers/gvisor-tap-vsock gvisor-tap-vsock-android

GOOS=android GOARCH=arm64 make

### Create a rootfs
```
$ mkdir rootfs
$ dd if=/dev/zero of=debian.img bs=1M count=32000
$ sudo mkfs.ext4 debian.img
$ sudo mount debian.img rootfs/
$ sudo debootstrap --arch=arm64 buster rootfs/
$ echo "vm" | sudo tee ./rootfs/etc/hostname
$ sudo mkdir -p ./rootfs/etc/systemd/resolved.conf.d/
$ sudo nvim ./rootfs/etc/systemd/resolved.conf.d/dns_servers.conf
```
Set the value to the following

[Resolve]

DNS=8.8.8.8 1.1.1.1
```
$ sudo chroot ./rootfs /bin/bash
$ useradd -m -g sudo <username>
$ passwd <username>
$ chsh -s /bin/bash <username>
$ exit
$ sudo mkdir -p ./rootfs/gvisor-tap-vsock/bin
$ sudo cp -r ./gvisor-tap-vsock-arm64/bin/* ./rootfs/gvisor-tap-vsock/bin
$ sudo umount ./rootfs
```

### Prepare the files

tar -czvf gvisor-tap-vsock-android.tar.gz ./gvisor-tap-vsock-android/bin/*

### Network
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

### Install Termux from F-Droid.

In Termux:
```
# termux-setup-storage
# mkdir kvm
```

Copy packages to the phone in /data/data/com.termux/files/home/kvm

debian.img

gvisor-tap-vsock-android.tar.gz

network.sh

./linux-x.x.xx/arch/arm64/boot/Image


In termux:
```
# su
# cd /data/data/com.termux/files/home/kvm
# chmod +x network.sh
# ./network.sh
```

```
# cd /data/data/com.termux/files/home/kvm
# tar -xvf gvisor-tap-vsock-android.tar.gz
# cd gvisor-tap-vsock-android/bin
# su
# chmod +x gvproxy
# ./gvproxy -debug -listen vsock://:1024 -listen unix:///data/data/com.termux/files/home/kvm/network.sock
```

In a new session termux
```
# su
# cd /apex/com.android.virt/bin
# ./crosvm run --disable-sandbox --net tap-name=crosvm_tap -s /data/data/com.termux/files/home/kvm/crosvm.sock --shared-dir "/data/data/com.termux/files/home/host_shared_dir:my_shared_tag:type=fs" -p 'init=/sbin/init' --rwroot /data/data/com.termux/files/home/kvm/debian.img /data/data/com.termux/files/home/kvm/Image --vsock 3 --mem 2048 --cpus 8
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
```
ssh <username>@192.168.10.2
```

Stop VM

In a new session termux
```
# su
# cd /apex/com.android.virt/bin
# ./crosvm stop /data/data/com.termux/files/home/kvm/crosvm.sock
```

### GUI via VNC, Xserver XSDL

In the guest

```
$ sudo apt install tightvncserver xfce4 xfce4-terminal xfce4-goodies
```

For VNC

In a new session termux
```
# ssh -L 5901:127.0.0.1:5901 -C -N -l <username> 192.168.10.2
```

In the guest
```
$ vncserver
```
Setting vncserver

Install vncviewer app on your phone

Open vncviewer app
```
localhost

5901

vncserver's password
```

For Xserver XSDL

Install Xserver XSDL app

Run commands from screen app

### Shared dir

In termux
```
# mkdir host_shared_dir
# su
# cd /apex/com.android.virt/bin
# ./crosvm run --disable-sandbox --shared-dir "/data/data/com.termux/files/home/host_shared_dir:my_shared_tag:type=fs" -p 'init=/sbin/init' --rwroot /data/data/com.termux/files/home/kvm/debian.img /data/data/com.termux/files/home/kvm/Image
```

In the guest
```
$ sudo su
$ mkdir /tmp/guest_shared_dir
$ mount -t virtiofs my_shared_tag /tmp/guest_shared_dir
```
Use /tmp/guest_shared_dir and /data/data/com.termux/files/home/host_shared_dir

### Troubleshooting

ping 8.8.8.8 work but network cant

Solution: enable hotspot on android

ping 8.8.8.8 Network is unreachable

Solution: again in the guest sudo chmod +x gvforwarder

read from remote host 192.168.10.2: software caused connection abort client_loop: send disconnect: broken pipe

Solution: VPN off

ERRO[0000] gvproxy exiting: cannot listen: listen unix /data/data/com.termux/files/home/kvm/network.sock: bind: address already in use

Solution: delete network.sock

ERRO[0000] gvproxy exiting: cannot add network services: listen tcp 127.0.0.1:2222: bind: address already in use

Solution: reboot phone

ERRO[0000] socket: address family not supported by protocol

Solution: enable CONFIG_VSOCKETS=y

Connection closed by {ip_address} or  error: kex_exchange_identification: Connection closed by remote host

Solution: install openssh-server or make linux distro with openssh-server

ERRO[0000] dhcp not found

Solution: make linux distro with dhclient

### How to make it in termux

[For termux](https://github.com/bvucode/Crosvm-on-android/blob/main/termux.md)

### Additional features

Run multiple virtual machines from other directories with new Crosvm, Linux Distro, Image and etc.

