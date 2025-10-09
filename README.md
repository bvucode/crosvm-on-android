# Run Linux on Android without AVF support

### Good to Mention

* The device used here is a Xiaomi Poco C65 phone running Android 15 (can work on android 14 linux 6.1)
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

```
# cd /data/data/com.termux/files/home/kvm
# tar -xvf gvisor-tap-vsock-android.tar.gz
```
### Network

[Network instruction](https://github.com/bvucode/Crosvm-on-android/blob/main/network.md)

### VM

Start VM

In a new session termux
```
# su
# cd /apex/com.android.virt/bin
# ./crosvm run --disable-sandbox --net tap-name=crosvm_tap -s /data/data/com.termux/files/home/kvm/crosvm.sock --shared-dir "/data/data/com.termux/files/home/host_shared_dir:my_shared_tag:type=fs" -p 'init=/sbin/init' --rwroot /data/data/com.termux/files/home/kvm/debian.img /data/data/com.termux/files/home/kvm/Image --vsock 3 --mem 2048 --cpus 8
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

### GPU acceleration is working

```
   1 OpenGL ES 2.x information:
   2   version: "OpenGL ES 3.1 Mesa 22.3.6"
   3   shading language version: "OpenGL ES GLSL ES 3.10"
   4   vendor: "Mesa/X.org"
   5   renderer: "virgl (Mali-G52 MC2)"
```

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

ERROR crosvm exiting with error 1: failed to create control server Caused by: Address already in use (os error 98)

Solution: delete crosvm.sock

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

In termux
```
# su
# chmod +x crosvm
# ./crosvm run --disable-sandbox --block /data/data/com.termux/files/home/ubuntu.img,root -p 'root=/dev/vda' /data/data/com.termux/files/home/Image
```










