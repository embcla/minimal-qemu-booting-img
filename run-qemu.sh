#!/bin/bash
LINUX_VER="linux-6.9.3"
BUSYBOX_VER="busybox-1.36.1"
HOME_DIR=${pwd}

mkdir -p tmp
cd tmp
TMP_DIR=${pwd}
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/${LINUX_VER}.tar.xz
tar -xf ${LINUX_VER}.tar.xz

cd ${LINUX_VER}
LINUX_DIR=${pwd}
cp $HOME_DIR/configs/kernel-config ${LINUX_DIR}/.config
make 
cp ${LINUX_DIR}/arch/x86_64/boot/bzImage ${HOME_DIR}/images

cd ${TMP_DIR}
wget https://busybox.net/downloads/${BUSYBOX_VER}.tar.bz2
tar -xf ${BUSYBOX_VER}.tar.bz2
cd ${BUSYBOX_VER}
BUSYBOX_DIR=${pwd}
cp ${HOME_DIR}/configs/busybox-config ${BUSYBOX_DIR}/.config
make install


cd ${HOME_DIR}/images
dd if=/dev/zero of=initrd.img BS=16M count=1
mkfs.ext4 initrd.img
cd ..

mkdir rootfs
sudo mount -o loop images/initrd.img rootfs
cp configs/tinyinit rootfs/init
cp busybox-1.36.1/_install/* rootfs
cd rootfs
sudo mknod dev/ram b 1 0
sudo mknod dev/console c 5 1
cd ..
sudo umount rootfs



# find -print0 | cpio -0oH newc | gzip -9 > ../../initramfs.cpio.gz

# qemu-system-x86_64 -kernel linux-6.9.3/arch/x86_64/boot/bzImage -initrd initramfs.cpio.gz -append "root=/dev/ram init=/myinitc" -m 512M

qemu-system-x86_64 -kernel images/bzImage -initrd images/initrd.img -append "root=/dev/ram init=/init" -m 128M
