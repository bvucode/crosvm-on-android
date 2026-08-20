# Run Linux on Android without AVF support

### Good to Mention

* The device used here is a Xiaomi Poco C65 phone running Android 15 (can work on android 14 linux 6.1)
* Unlock bootloader
* You need a [rooted](https://en.m.wikipedia.org/wiki/Rooting_(Android)) device
* If you damage your device in any way, you are all responsible for it!

### Result of command from Poco C65
```
su
getprop | grep hypervisor
[ro.boot.hypervisor.version]: [GenieZone]
[ro.boot.hypervisor.vm.supported]: [1]
```

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

### Create rootfs

#### Debian
```
$ mkdir rootfs
$ dd if=/dev/zero of=debian.img bs=1M count=32000
$ sudo mkfs.ext4 debian.img
$ sudo mount debian.img rootfs/
$ sudo debootstrap --arch=arm64 buster rootfs/
$ sudo cp -r linux-6.16.12 ./rootfs
$ echo "vm" | sudo tee ./rootfs/etc/hostname
$ sudo mkdir -p ./rootfs/etc/systemd/resolved.conf.d/
$ sudo nvim ./rootfs/etc/systemd/resolved.conf.d/dns_servers.conf
```
Set the value to the following

[Resolve]

DNS=8.8.8.8 1.1.1.1
```
$ sudo chroot ./rootfs /bin/bash
$ apt install build-essential
$ cd /linux-6.16.12
$ make install
$ cd /
$ apt remove build-essential
$ rm -rf /linux-6.16.12
$ useradd -m -g sudo <username>
$ passwd <username>
$ chsh -s /bin/bash <username>
$ exit
$ cd linux-6.16.12
$ sudo make modules_install INSTALL_MOD_PATH=/home/rootfs
$ cd ../
```

Not required if using the network configuration method Network: Official method networking from Crosvm docs modified for Android
```
$ sudo mkdir -p ./rootfs/gvisor-tap-vsock/bin
$ sudo cp -r ./gvisor-tap-vsock-arm64/bin/* ./rootfs/gvisor-tap-vsock/bin
```

```
$ sudo umount ./rootfs
```
#### Arch Linux
```
$ curl -LO http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
$ curl -LO http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz.md5
$ md5sum -c ArchLinuxARM-aarch64-latest.tar.gz.md5
$ sudo dd if=/dev/zero of=arch-rootfs.img bs=1M count=32000
$ sudo mkfs.ext4 arch-rootfs.img
$ sudo losetup --find --show arch-rootfs.img
$ mkdir rootfs
$ sudo mount /dev/loop0 rootfs
$ sudo tar -xvf ArchLinuxARM-aarch64-latest.tar.gz -C rootfs
$ sudo cp -r linux-6.16.12 ./rootfs
$ sudo arch-chroot rootfs /bin/bash
$ pacman-key --init
$ pacman-key --populate archlinuxarm
$ pacman -Rnd linux-aarch64
$ pacman -S base-devel --noconfirm
$ cd /linux-6.16.12
$ make install
$ cd /
$ rm -rf /linux-6.16.12
$ useradd -m -g wheel <username>
$ passwd <username>
$ chsh -s /bin/bash <username>
$ exit
$ cd linux-6.16.12
$ sudo make modules_install INSTALL_MOD_PATH=/home/rootfs
$ cd ../
$ echo "vm" | sudo tee ./rootfs/etc/hostname
$ sudo mkdir -p ./rootfs/etc/systemd/resolved.conf.d/
$ sudo nvim ./rootfs/etc/systemd/resolved.conf.d/dns_servers.conf
```
Set the value to the following

[Resolve]

DNS=8.8.8.8 1.1.1.1
```
$ sudo umount -l rootfs/
$ sudo losetup -d /dev/loop0
```
#### Create rootfs in Termux

```
# pkg install debootstrap
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
$ sudo apt install tightvncserver xfce4 xfce4-terminal xfce4-goodies dbus-x11
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

### GPU acceleration

> [!NOTE]
> **MediaTek Hypervisor Support**: Crosvm from Android 16 features native support for the MediaTek Geniezone hypervisor. It communicates directly with the `/dev/gzvm` driver out of the box, bypasssing the need for any additional Android Virtualization Framework (AVF) patches or wrappers for basic CPU and memory mapping.

* Android 15 requires using Crosvm from Android 16 (available in Releases).
* Provides Debian and Ubuntu GUI acceleration via KasmVNC.

#### Prerequisites

1. Build your guest kernel with the following options and run `make modules_install`:
   ```ini
   CONFIG_DRM=m
   CONFIG_DRM_VIRTIO_GPU=y
   ```
2. Inside the guest OS, initialize the VNC server pointing to the virtual GPU node:
   ```bash
   vncserver -hw3d -drinode /dev/dri/renderD128
   ```

#### Launching Crosvm with GPU

Execute the following command as `root` inside Termux:

```bash
# su
# chmod +x crosvm16
# LD_PRELOAD=./libbinder_ndk.so:./libbinder.so ./crosvm16 --log-level debug run --disable-sandbox --gpu backend=virglrenderer,surfaceless=true,egl=true,gles=true,context-types=virgl2
```

#### Expected Debug Output

When running with `--log-level debug`, you should verify that Crosvm successfully catches the MediaTek hypervisor device and initializes the host GPU driver (`mali_kbase`):

```text
[2026-08-20T13:44:59.108618039+00:00 DEBUG crosvm::crosvm::sys::linux] creating hypervisor: Geniezone { device: Some("/dev/gzvm") }
[2026-08-20T13:44:59.111563270+00:00 INFO  crosvm::crosvm::sys::linux::device_helpers] Trying to attach block device: /data/data/com.termux/files/home/arch/arch-rootfs.img
[2026-08-20T13:44:59.111870962+00:00 INFO  disk] disk size 10737418240
Could not open module param file '/sys/module/mali_kbase/parameters/large_page_conf'
[2026-08-20T13:44:59.422502423+00:00 INFO  rutabaga_gfx::virgl_renderer] gl_version 32 - es profile enabled

[2026-08-20T13:44:59.460083577+00:00 ERROR devices::virtio::gpu] failed to open display: unsupported by the implementation
[2026-08-20T13:44:59.906966962+00:00 DEBUG devices::usb::xhci] xhci_controller: halt device
[2026-08-20T13:44:59.907191039+00:00 DEBUG devices::usb::xhci] xhci_controller: interrupter enable?: false
[    0.000000] Booting Linux on physical CPU 0x0000000000 [0x411fd050]
```

#### Verified Guest Graphics Info

Once booted, running diagnostic tools inside the guest OS will confirm that the rendering pipeline maps directly to your hardware (e.g., Mali GPU):

```text
   OpenGL ES 2.x information:
      version: "OpenGL ES 3.1 Mesa 22.3.6"
      shading language version: "OpenGL ES GLSL ES 3.10"
      vendor: "Mesa/X.org"
      renderer: "virgl (Mali-G52 MC2)"
```


### Troubleshooting

ping 8.8.8.8 work but network cant

Solution: enable hotspot on android and correct date

ping 8.8.8.8 Network is unreachable

Solution: again in the guest sudo chmod +x gvforwarder and correct date

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

One of the kernel panic errors occurs because adb transfer may corrupts files

Solution: try copy or scp

### Download rootfs and Image

Debian, Arch Linux rootfs, Image from Releases

Increase size rootfs

### Additional features

Run Windows

```
sudo qemu-system-x86_64 \
  -m 768 \
  -smp 1 \
  -boot c \
  -drive file=/home/droid/7.vhd,if=ide,format=vpc \
  -vnc 0.0.0.0:0 \
  -device virtio-gpu-pci
```

Run multiple virtual machines from other directories with new Crosvm, Linux Distro, Image and etc.

In termux
```
# su
# chmod +x crosvm
# ./crosvm run --disable-sandbox --block /data/data/com.termux/files/home/ubuntu.img,root -p 'root=/dev/vda' /data/data/com.termux/files/home/Image
```
























