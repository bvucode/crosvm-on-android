# All files in Releases

### Install Termux from F-Droid.

In Termux
```
# pkg install sudo debootstrap
# su dd if=/dev/zero of=ubuntu.img bs=1M count=4000
# sudo mkfs.ext4 ubuntu.img
# sudo mkdir rootfs/
# sudo mount ubuntu.img rootfs/
# sudo debootstrap --arch=arm64 --include=sudo,openssh-server jammy rootfs/
# sudo nvim rootfs/etc/passwd
after root delete x
# echo "vm" | sudo tee ./rootfs/etc/hostname
# sudo mkdir -p ./rootfs/etc/systemd/resolved.conf.d/
```

```
# sudo nvim ./rootfs/etc/systemd/resolved.conf.d/dns_servers.conf
```

Set the value to the following

[Resolve]

DNS=8.8.8.8 1.1.1.1

```
# sudo mkdir -p ./rootfs/gvisor-tap-vsock/bin
# sudo cp -r ./gvisor-tap-vsock-arm64/bin/* ./rootfs/gvisor-tap-vsock/bin
# sudo umount rootfs/
```

Copy ubuntu.img and Image in /data/local/tmp

```
# su
# cd /apex/com.android.virt/bin
# ./crosvm run --disable-sandbox --block /data/local/tmp/ubuntu.img,root -p 'root=/dev/vda' /data/local/tmp/Image
```
In the guest
```
useradd -m -g users <username>
passwd <username>
sudo usermod -a -G sudo <username>

```
