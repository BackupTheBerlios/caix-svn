#!/bin/sh

curdir=$(pwd)

patch <sqmakefile.patch
cd lzmasdk
patch -p1 <../sqlzma1-449.patch
cd ../squashfs3.3
patch -p1 <../sqlzma2u-3.3.patch
cd /usr/src/linux/
patch -p1 < ${curdir}/sqlzma2k-3.3.patch

cd ${curdir}

lpath=$(readlink /usr/src/linux)
KERNEL_VERSION=${lpath:6}
echo KVER=${KERNEL_VERSION} >kver.mk

make clean
make

cp lzmasdk/C/Compress/Lzma/kmod/sqlzma.ko /lib/modules/${KERNEL_VERSION}/kernel/fs/squashfs
cp lzmasdk/C/Compress/Lzma/kmod/unlzma.ko /lib/modules/${KERNEL_VERSION}/kernel/fs/squashfs
cp /usr/src/linux/fs/squashfs/*.ko /lib/modules/${KERNEL_VERSION}/kernel/fs/squashfs

depmod -a ${KERNEL_VERSION}


