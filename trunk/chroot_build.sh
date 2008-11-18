#!/bin/bash
#
# chroot_build.sh   build tasks in chroot environment.
#
# This work is part of CAIX (http://caix.berlios.de).
# Copyright (C) 2008 Andreas Leipelt
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA 02111-1307 USA
#

source /root/livecd.conf

STDPKGS="syslinux grub gentoolkit livecd-tools CSP"

function die() {
    echo $1 > /error.occured
    exit 1
}

#
# compile sqlzma kernel modules and tools
#
function squashfs_lzma_support() {
    s=$(readlink /usr/src/linux)
    KERNEL_VER=${s:6}

    if [ -e /tmp/squashfs-lzma ]; then
        cd /tmp/squashfs-lzma
        ./sqcompile.sh
        [ "$?" != "0" ] && die "Compilation of sqlzma kernel modules failed."
    fi

    RAMFSDIR="/tmp/initramfs"

    mkdir -p ${RAMFSDIR}
    cd ${RAMFSDIR}
    gunzip < /boot/initramfs-genkernel-x86-${KERNEL_VER} | cpio -i -H newc
    [ "$?" != "0" ] && die "Unpacking of initramfs image failed."

    mkdir -p ${RAMFSDIR}/lib/modules/${KERNEL_VER}/kernel/fs/squashfs/
    cp /lib/modules/${KERNEL_VER}/kernel/fs/squashfs/*.ko ${RAMFSDIR}/lib/modules/${KERNEL_VER}/kernel/fs/squashfs/
    [ "$?" != "0" ] && die "Copying of squashfs.ko failed."

    if [ -e /tmp/squashfs-lzma ]; then
        echo unlzma >>${RAMFSDIR}/etc/modules/fs
        echo sqlzma >>${RAMFSDIR}/etc/modules/fs
    fi

    echo squashfs >>${RAMFSDIR}/etc/modules/fs
    find . | cpio -o -H newc | gzip > /boot/initramfs-genkernel-x86-${KERNEL_VER}
    [ "$?" != "0" ] && die "Creation of initramfs image failed."
    cd /
}

function build_kernel() {
    emerge -kuDN util-linux genkernel dmraid evms lvm2
    [ "$?" != "0" ] && die "emerge failed."

    if [ "{KERNEL}" == "" ]; then
        emerge gentoo-sources
    else
        emerge =${KERNEL}
    fi
    [ "$?" != "0" ] && die "emerge failed on kernel sources."

    genkernel --dmraid --evms --luks --lvm --kernel-config=/etc/kernels/${KERNEL_CONF} all
    [ "$?" != "0" ] && die "Kernel compilation failed."

    squashfs_lzma_support
}

function bring_in_packages() {
    emerge -kuDN system
    [ "$?" != "0" ] && die "emerge -kuDN system failed."

    emerge -kuDN world
    [ "$?" != "0" ] && die "emerge -kuDN world failed."

    emerge -kuDN ${STDPKGS}
    [ "$?" != "0" ] && die "emerge -kuDN ${STDPKGS} failed."

    emerge -kuDN ${PKGLIST}
    [ "$?" != "0" ] && die "emerge -kuDN ${PKGLIST} failed."

    revdep-rebuild
    [ "$?" != "0" ] && die "revdep-rebuild failed"

    echo -5 | etc-update
}

#
# make a list of files to clean
#
function clean_files() {
    for p in $(echo $1); do
        equery files $p | grep -v "* Contents of " >> ~/clean.list
    done
}

function clean_info() {
    clean_files "${PKGRMLIST}"

    if [ "${KEED_CPP_SO}" == "yes" ]; then
        equery files gcc | grep -v "* Contents of " | grep -v "^/usr/lib/gcc/" | grep -v libstdc++ >> ~/clean.list
    fi
}

function configure_system() {
    for s in `echo ${SERVICES}`; do
        rc-update add ${s} default
    done

    sed s/"# include"/include/ -i /etc/nanorc
    sed s/"\\\.sh"/"\\\.\(sh|cfg|conf|config|cnf|ini\)"/ -i /usr/share/nano/sh.nanorc
}

#
#  main
#
env-update
source /etc/profile

build_kernel
bring_in_packages
configure_system
clean_info
