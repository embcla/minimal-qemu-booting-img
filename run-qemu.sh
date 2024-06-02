#!/bin/bash

mkdir -p tmp
cd tmp
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.9.3.tar.xz
tar -xvf linux-6.9.3.tar.xz

cd linux-6.9.3
make i386_defconfig
make -j8