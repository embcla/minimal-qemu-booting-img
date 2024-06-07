#!/bin/bash

# -- Global Variables
VER_KERNEL="linux-6.9.3"
VER_BUSYBOX="busybox-1.36.1"

DIR_HOME=$PWD
DIR_IMAGES=${DIR_HOME}/images
DIR_KERNEL=${DIR_HOME}/${VER_KERNEL}
DIR_BUSYBOX=${DIR_HOME}/${VER_BUSYBOX}

IMG_KERNEL=${DIR_IMAGES}/bzImage
IMG_BUSYBOX=${DIR_IMAGES}/initrd.img

VAR_KERNEL_FOUND=0
VAR_BUSYBOX_FOUND=0
VAR_KERNEL_BUILT=0
VAR_BUSYBOX_BUILT=0
VAR_OPTS_INVALID=1
VAR_UPDATE_BOOTIMG=0

# set -eu

download_kernel()
{
    echo "Downloading linux kernel ver $VER_KERNEL"
    DIR_TMP=$(mktemp -d -t)
    cd $DIR_TMP
    wget https://cdn.kernel.org/pub/linux/kernel/v6.x/${VER_KERNEL}.tar.xz
    if [ ! $? -eq 0 ]; then
        echo "There was an error downloading the kernel, please fix it an try again"
        exit 1;
    fi
    echo "Uncompressing kernel archive"
    mkdir -p $DIR_KERNEL
    tar -xf ${VER_KERNEL}.tar.xz -C $DIR_HOME
    if [ ! $? -eq 0 ]; then
        echo "There was an error uncompressing the kernel, please fix it an try again"
        exit 1;
    fi
}

download_busybox()
{
    echo "Downloading busybox ver $VER_BUSYBOX"
    DIR_TMP=$(mktemp -d -t)
    cd $DIR_TMP
    wget https://busybox.net/downloads/${VER_BUSYBOX}.tar.bz2
    if [ ! $? -eq 0 ]; then
        echo "There was an error downloading busybox, please fix it an try again"
        exit 1;
    fi
    echo "Uncompressing busybox archive"
    mkdir -p $DIR_BUSYBOX
    tar -xf ${VER_BUSYBOX}.tar.bz2 -C $DIR_HOME
    if [ ! $? -eq 0 ]; then
        echo "There was an error uncompressing busybox, please fix it an try again"
        exit 1;
    fi
}

check_create_images_folder()
{
    if [ ! -d "${DIR_IMAGES}" ]; then
        mkdir -p ${DIR_IMAGES}
    fi
    if [ ! $? -eq 0 ]; then
        echo "There was an error creating the images folder, please fix it an try again"
        exit 1;
    fi
}

clean_kernel()
{
    cd ${DIR_KERNEL}
    make clean
    if [ ! $? -eq 0 ]; then
        echo "There was an error while cleaning the kernel, please fix it an try again"
        exit 1;
    fi
}

build_kernel()
{
    echo "Building kernel, using $(nproc) cores"
    cp ${DIR_HOME}/configs/kernel-config ${DIR_KERNEL}/.config
    cd ${DIR_KERNEL}
    make -j$(nproc) 2>&1
    cp ${DIR_KERNEL}/arch/x86_64/boot/bzImage ${DIR_IMAGES}
    if [ ! $? -eq 0 ]; then
        echo "There was an error while building the kernel, please fix it an try again"
        exit 1;
    fi
}

clean_busybox()
{
    cd ${DIR_BUSYBOX}
    make clean
    if [ ! $? -eq 0 ]; then
        echo "There was an error while cleaning buildroot, please fix it an try again"
        exit 1;
    fi
}

build_busybox()
{
    echo "Building busybox, using $(nproc) cores"
    cp ${DIR_HOME}/configs/busybox-config ${DIR_BUSYBOX}/.config
    cd ${DIR_BUSYBOX}
    make -j$(nproc) 2>&1
    if [ ! $? -eq 0 ]; then
        echo "There was an error while building busybox, please fix it an try again"
        exit 1;
    fi
    make install 2>&1
    if [ ! $? -eq 0 ]; then
        echo "There was an error while building busybox, please fix it an try again"
        exit 1;
    fi
    VAR_UPDATE_BOOTIMG=1
}

generate_bootimg()
{
    echo "Generating boot img"
    cd ${DIR_IMAGES}
    dd if=/dev/zero of=${IMG_BUSYBOX} bs=16M count=1
    if [ ! $? -eq 0 ]; then
        echo "There was an error creating the raw boot image, please fix it an try again"
        exit 1;
    fi
    mkfs.ext4 ${IMG_BUSYBOX}
    if [ ! $? -eq 0 ]; then
        echo "There was an error setting the filesystem of the boot image, please fix it an try again"
        exit 1;
    fi
    cd ${DIR_HOME}
}


setup_bootimg()
{
    echo "Adding rootfs to boot img"
    mkdir -p ${DIR_HOME}/rootfs
    sudo mount -o loop ${IMG_BUSYBOX} rootfs
    if [ ! $? -eq 0 ]; then
        echo "Mounting rootfs failed, please fix it an try again"
        exit 1;
    fi
    sudo cp -r ${DIR_HOME}/configs/tinyinit rootfs/init
    sudo cp -r ${DIR_BUSYBOX}/_install/* rootfs
    cd rootfs
    sudo mkdir -p proc sys tmp dev
    sudo mknod dev/ram b 1 0
    sudo mknod dev/console c 5 1
    cd ${DIR_HOME}
    sudo umount rootfs
}

run_qemu()
{
    echo "Starting QEMU simulation"
    cd ${DIR_HOME}
    qemu-system-x86_64 -kernel images/bzImage -initrd images/initrd.img -append "root=/dev/ram init=/init" -m 128M -display gtk
}


# # find -print0 | cpio -0oH newc | gzip -9 > ../../initramfs.cpio.gz

# # qemu-system-x86_64 -kernel linux-6.9.3/arch/x86_64/boot/bzImage -initrd initramfs.cpio.gz -append "root=/dev/ram init=/myinitc" -m 512M

check_images()
{
    if [[ -e ${IMG_KERNEL} ]]; then
        echo "Kernel image found, use it or regenerate it (u/r)?"
        read choice
        allowed="u|r"
        if [[ "${choice}" =~ ^($allowed)$ ]]; then
            # VAR_KERNEL_FOUND=1
            case "${choice}" in
                u)
                    echo "Using existing image"
                    VAR_KERNEL_BUILT=1
                    VAR_OPTS_INVALID=0
                    ;;
                r)
                    echo "Rigenerating kernel image"
                    VAR_OPTS_INVALID=0
                    VAR_KERNEL_CLEAN=1
                    ;;
            esac
        else
            echo "Please use \"u\" or \"r\""
            VAR_OPTS_INVALID=1
            return
        fi
    else
        echo "Kernel image not found, generating with defaults"
        VAR_OPTS_INVALID=0
    fi

    if [[ -e ${IMG_BUSYBOX} ]]; then
        echo "Busybox image found, use it or regenerate it (u/r)?"
        read choice
        allowed="u|r"
        if [[ "${choice}" =~ ^($allowed)$ ]]; then
            # VAR_BUSYBOX_FOUND=1
            case "${choice}" in
                u)
                    echo "Using existing image"
                    VAR_BUSYBOX_BUILT=1
                    VAR_OPTS_INVALID=0
                    ;;
                r)
                    echo "Rigenerating busybox image"
                    VAR_OPTS_INVALID=0
                    VAR_BUSYBOX_CLEAN=1
                    ;;
            esac
        else
            echo "Please use \"u\" or \"r\""
            VAR_OPTS_INVALID=1
        fi
    else
        echo "Busybox image not found, generating with defaults"
        VAR_OPTS_INVALID=0
    fi

    if [[ $VAR_BUSYBOX_BUILT -eq 1 ]]; then
        echo "Do you want to update the boot image init script? (y/n)"
        read choice
        allowed="y|n"
        if [[ "${choice}" =~ ^($allowed)$ ]]; then
            case "${choice}" in
                y)
                    VAR_UPDATE_BOOTIMG=1
                    ;;
                n)
                    ;;
            esac
        fi
    fi
}

get_user_notice_acceptance()
{
    echo -e \
    "\n\n   This script will attempt to do the following\n \
    * build Linux Kernel $VER_KERNEL\n \
    * build Busybox $VER_BUSYBOX\n \
    * run the above in a custom QEMU image\n\n \
         
    DISCLAIMER: the build systems of the Kernel and of\n \
    Busybox do not automatically check of pre-requisites.\n \
    You, the user, are required to manually sort out necessary\n \
    dependencies for everything. Please check the dependencies\n \
    of Kernel, Busybox, QEMU and act accordingly.\n\n \

    Do you wish to proceed? (y/n)"
        read choice
        allowed="y|n"
        if [[ "${choice}" =~ ^($allowed)$ ]]; then
            case "${choice}" in
                y)
                    return
                    ;;
                n)
                    exit 0
                    ;;
            esac
        else
            echo "Please use \"y\" or \"n\""
            exit 0;
        fi
}

main()
{
    get_user_notice_acceptance

    while [ $VAR_OPTS_INVALID -eq "1" ]; do
        check_images
    done

    check_create_images_folder

    if [[ $VAR_KERNEL_BUILT -eq 0 ]]; then
        if [ ! -d "$DIR_KERNEL" ]; then
            download_kernel
        fi
        if [[ $VAR_KERNEL_CLEAN -eq 1 ]]; then
            clean_kernel
        fi
        build_kernel
        VAR_UPDATE_BOOTIMG=1
    fi

    if [[ $VAR_BUSYBOX_BUILT -eq 0 ]]; then
        if [ ! -d "$DIR_BUSYBOX" ]; then
            download_busybox
        fi
        if [[ $VAR_BUSYBOX_CLEAN -eq 1 ]]; then
            clean_busybox
        fi
        build_busybox
        VAR_UPDATE_BOOTIMG=1
    fi

    if [[ $VAR_UPDATE_BOOTIMG -eq 1 ]]; then
        generate_bootimg
        setup_bootimg
    fi

    run_qemu
}

main "${@}"

exit 0