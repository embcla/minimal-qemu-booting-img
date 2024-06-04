#!/bin/bash

# set -eu

# LINUX_VER="linux-6.9.3"
# BUSYBOX_VER="busybox-1.36.1"
# HOME_DIR=$PWD
# TMP_DIR=mktemp -d -t
# IMG_KERNEL=images/bzImage
# IMG_BUSYBOX=images/initrd.img

# cd $TMP_DIR
# wget https://cdn.kernel.org/pub/linux/kernel/v6.x/${LINUX_VER}.tar.xz
# tar -xf ${LINUX_VER}.tar.xz

# cd ${LINUX_VER}
# LINUX_DIR=$PWD
# cp ${HOME_DIR}/configs/kernel-config ${LINUX_DIR}/.config
# make -j$(nproc) 2>&1
# cp ${LINUX_DIR}/arch/x86_64/boot/bzImage ${HOME_DIR}/${IMG_KERNEL}

# cd ${TMP_DIR}
# wget https://busybox.net/downloads/${BUSYBOX_VER}.tar.bz2
# tar -xf ${BUSYBOX_VER}.tar.bz2
# cd ${BUSYBOX_VER}
# BUSYBOX_DIR=$PWD
# cp ${HOME_DIR}/configs/busybox-config ${BUSYBOX_DIR}/.config
# make -j$(nproc) install 2>&1



# dd if=/dev/zero of=${IMG_BUSYBOX} bs=16M count=1
# mkfs.ext4 ${IMG_BUSYBOX}
# cd ${HOME_DIR}

# mkdir -p ${HOME_DIR}/rootfs
# sudo mount -o loop ${HOME_DIR}/${IMG_BUSYBOX} rootfs
# sudo cp -r ${HOME_DIR}/configs/tinyinit rootfs/init
# sudo cp -r ${BUSYBOX_DIR}/_install/* rootfs
# cd rootfs
# sudo mkdir -p proc sys tmp dev
# sudo mknod dev/ram b 1 0
# sudo mknod dev/console c 5 1
# cd ..
# sudo umount rootfs



# # find -print0 | cpio -0oH newc | gzip -9 > ../../initramfs.cpio.gz

# # qemu-system-x86_64 -kernel linux-6.9.3/arch/x86_64/boot/bzImage -initrd initramfs.cpio.gz -append "root=/dev/ram init=/myinitc" -m 512M

# qemu-system-x86_64 -kernel images/bzImage -initrd images/initrd.img -append "root=/dev/ram init=/init" -m 128M

main()
{
    if [ -e ${IMG_KERNEL} ]
    then
        echo "Kernel image found, use it or regenerate it (u/r)?"
        read choice
        allowed="u|r"
        if [[ "${choice}" =~ ^($allowed)$ ]]; then
            case "${choice}" in
                u)
                    echo "Using existing image"
                    exit 0
                    ;;
                r)
                    echo "Rigenerating kernel image"
                    exit 0
                    ;;
            esac
        else
            echo "Please use \"u\" or \"r\""
        fi
    else
        echo "Kernel image not found, generating with defaults"
    fi
}

main "${@}"

exit 0