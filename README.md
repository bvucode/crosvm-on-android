# How to boot linux in a vm on Android 15+

Guide originally by Christopher L. Crutchfield. Modified and added to by Bulat Valiakhmetov.

## Good to Mention

* The device used here is a Xiaomi Poco C65 phone running Android 15
* Unlock bootloader
* You need a [rooted](https://en.m.wikipedia.org/wiki/Rooting_(Android)) device
* If you damage your device in any way, you are all responsible for it!

## Install dependencies
```
$ sudo apt install build-essential debootstrap qemu-user-static gcc-aarch64-linux-gnu atftpd nfs-kernel-server fdisk libcap-dev libgbm-dev libvirglrenderer-dev libwayland-bin libwayland-dev pkg-config protobuf-compiler bc bison flex libssl-dev make libc6-dev libncurses5-dev crossbuild-essential-arm64

$ rm -rf /usr/local/go && tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
```

Add this to your ~/.bashrc

export PATH=$PATH:/usr/local/go/bin

## Build the kernel

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
## Cross-compile gVisor Proxy for aarch64

git clone https://github.com/containers/gvisor-tap-vsock gvisor-tap-vsock-arm64

GOARCH=arm64 make

## Cross-compile gVisor Proxy for Android

git clone https://github.com/containers/gvisor-tap-vsock gvisor-tap-vsock-android

GOOS=android GOARCH=arm64 make

## Create a rootfs
```
$ mkdir vm-host
$ dd if=/dev/zero of=vm-host.img bs=1M count=1000
$ mkfs.ext4 vm-host.img
$ sudo mount vm-host.img vm-host
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
$ sudo mkdir -p ./rootfs/gvisor-tap-vsock
$ sudo cp -r ./gvisor-tap-vsock-arm64/bin/* ./rootfs/gvisor-tap-vsock
$ sudo mkdir -p ./vm-host/gvisor-tap-vsock
$ sudo cp -r ./gvisor-tap-vsock-android/bin/* ./vm-host/gvisor-tap-vsock
$ sudo umount ./rootfs
$ sudo umount ./vm-host
```

## Install Termux from F-Droid. In Termux:
```
# termux-setup-storage
# mkdir kvm
# mkdir ./kvm/vm-host
```
Copy packages to the phone in /data/data/com.termux/files/home/kvm

debian.img

vm-host.img

./linux-x.x.xx/arch/arm64/boot/Image
```
# su
# mount ./kvm/vm-host.img ./kvm/vm-host
# cd /data/data/com.termux/files/home/kvm/vm-host/gvisor-tap-vsock
# chmod +x gvproxy
# ./gvproxy -debug -listen vsock://:1024 -listen unix:///data/data/com.termux/files/home/kvm/vm-host/network.sock
```
In a new session termux
```
# su
# cd /apex/com.android.virt/bin
# ./crosvm run --disable-sandbox -p 'init=/sbin/init' --rwroot /data/data/com.termux/files/home/kvm/debian.img /data/data/com.termux/files/home/kvm/Image --vsock 3 --mem 1024 --cpus 2
```

In the guest
```
$ cd /gvisor-tap-vsock
$ sudo chmod +x gvforwarder
$ sudo ./gvforwarder --debug &
or
$ sudo ./gvforwarder --debug > /dev/null 2>&1 &
$ ping 8.8.8.8
```
### SSH
```
$ sudo mount vm-host.img vm-host/
$ sudo mount debian.img rootfs/
```
Install Linux Kernel Modules
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
Start VM Network Proxy at Boot
```
$ sudo nvim ./rootfs/lib/systemd/system/gvisor-network-proxy.service
```
Set the value to the following
```
[Unit]
Description=gvisor network proxy
After=network.target

[Service]
ExecStart=/gvisor-tap-vsock/gvforwarder
Restart=on-failure

[Install]
WantedBy=multi-user.target
```
```
$ sudo chroot ./rootfs /bin/bash
$ systemctl enable gvisor-network-proxy
$ exit
```
Creating Android Scripts

Download curl-aarch64 from https://github.com/moparisthebest/static-curl and place it into the vm-host directory.
```
$ cd ./vm-host
$ sudo chmod +x ./curl-aarch64
$ sudo nvim ./start-network.sh
```
Set the value to the following
```
#!/data/data/com.termux/files/usr/bin/sh

/data/data/com.termux/files/home/kvm/vm-host/gvisor-tap-vsock/gvproxy -listen vsock://:1024 -listen unix:///data/data/com.termux/files/home/kvm/vm-host/network.sock &
sleep 1
./curl-aarch64  --unix-socket /data/data/com.termux/files/home/kvm/vm-host/network.sock http:/unix/services/forwarder/expose -X POST -d '{"local":":22","remote":"192.168.127.2:22"}'
```
```
$ sudo chmod +x ./start-network.sh
$ sudo nvim ./start-vm.sh
```
Set the value to the following
```
#!/data/data/com.termux/files/usr/bin/sh

/apex/com.android.virt/bin/crosvm run --disable-sandbox -p 'init=/sbin/init' --rwroot /data/data/com.termux/files/home/kvm/debian.img /data/data/com.termux/files/home/kvm/Image --vsock 3 --mem 1024 --cpus 2
```
```
$ sudo chmod +x ./start-vm.sh
```
Unmount Directories
```
$ umount ./rootfs
$ umount ./vm-host
```

Copy packages to the phone in /data/data/com.termux/files/home/kvm

In termux
```
# su
# mount kvm/vm-host.img kvm/vm-host
# cd /kvm/vm-host
# ./start-network.sh
```
In a new session termux
```
# cd /kvm/vm-host
# ./start-vm.sh
```
SSH into the Phone

Grab the IP Address of the phone from its setting page.

On your technician machine, ssh <user>@<phone IP>. You should be connected to a machine with the hostname vm.

## GUI via VNC, Xserver XSDL

In the guest

```
$ sudo apt install tightvncserver, xfce4
```
Grab the IP Address of the phone from its setting page.

In a new session termux
```
# ssh -L 5901:127.0.0.1:5901 -C -N -l <user> <phone IP>
```
For vnc
```
$ vncserver
```

Setting vncserver

Install vncviewer app on your phone

Open vncviewer app

localhost

5901

vncserver's password

For Xserver XSDL

Install Xserver XSDL app

run commands from screen app

## Shared dir

In termux
```
# mkdir host_shared_dir
# su
# cd /apex/com.android.virt/bin
# ./crosvm run --disable-sandbox --shared-dir "/data/data/com.termux/files/home/host_shared_dir:my_shared_tag:type=fs" -p 'init=/sbin/init' --rwroot /data/data/com.termux/files/home/kvm/debian.img /data/data/com.termux/files/home/kvm/Image --vsock 3 --mem 1024 --cpus 2
```
In the guest

```
$ sudo su
$ mkdir /tmp/guest_shared_dir
$ mount -t virtiofs my_shared_tag /tmp/guest_shared_dir
```
Use /tmp/guest_shared_dir and /data/data/com.termux/files/home/host_shared_dir

## Troubleshooting

ping 8.8.8.8 work but network cant

Solution: enable hotspot on android

ping 8.8.8.8 Network is unreachable

Solution: again in the guest sudo chmod +x gvforwarder

ERRO[0000] gvproxy exiting: cannot listen: listen unix /data/data/com.termux/files/home/kvm/vm-host/network.sock: bind: address already in use

Solution: delete network.sock

ERRO[0000] gvproxy exiting: cannot add network services: listen tcp 127.0.0.1:2222: bind: address already in use

Solution: reboot phone

socket: address family not supported by protocol

Solution: enable CONFIG_VSOCKETS

Connection closed by {ip_address} or  error: kex_exchange_identification: Connection closed by remote host

Solution: install openssh-server or make linux distro with openssh-server

ERRO dhcp not found

Solution: make linux distro with dhclient
