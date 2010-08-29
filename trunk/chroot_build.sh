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

STDPKGS="syslinux grub livecd-tools"

function die() {
    echo $1 > /error.occured
    exit 1
}

#
# modify initramfs
#
function modify_initramfs() {
    s=$(readlink /usr/src/linux)
    KERNEL_VER=${s:6}

    RAMFSDIR="/tmp/initramfs"

    mkdir -p ${RAMFSDIR}
    cd ${RAMFSDIR}
    INITRAMFS=`ls /boot/initramfs-*`
    gunzip < ${INITRAMFS} | cpio -i -H newc
    [ "$?" != "0" ] && die "Unpacking of initramfs image failed."

    mkdir -p ${RAMFSDIR}/lib/modules/${KERNEL_VER}/kernel/fs/squashfs/
    cp /lib/modules/${KERNEL_VER}/kernel/fs/squashfs/*.ko ${RAMFSDIR}/lib/modules/${KERNEL_VER}/kernel/fs/squashfs/
    [ "$?" != "0" ] && die "Copying of squashfs.ko failed."

    echo squashfs >>${RAMFSDIR}/etc/modules/fs
    cp -R /initscripts/* ${RAMFSDIR}
    find . | cpio -o -H newc | gzip > ${INITRAMFS}
    [ "$?" != "0" ] && die "Creation of initramfs image failed."
    cd /
}

function useflags()
{
    emerge -k gentoolkit
    [ "$?" != "0" ] && die "emerge -k gentoolkit failed."

    uflaglist=$(echo $USE)
    for u in $uflaglist; do
        s=${u:0:1}
        if [ "$s" == "-" ]; then
            euse -D ${u:1}
        else
            euse -E ${u}
        fi
    done
    euse -E livecd
}

function build_makeconf() {
    rm -f /etc/make.conf
    grep MAKECONF_ /root/livecd.conf | cut -d'#' -f1 > /tmp/mconf.tmp
    sed s/MAKECONF_//g /tmp/mconf.tmp >/etc/make.conf
    rm /tmp/mconf.tmp
}

function build_kernel() {
    # emerge -kuDN util-linux genkernel dmraid evms lvm2
    emerge -kuDN genkernel dmraid lvm2
    [ "$?" != "0" ] && die "emerge failed."
    echo -5 | etc-update

    emerge -C gentoo-sources
    rm -rf /usr/src/linux

    if [ "${KERNEL}" == "" ]; then
        emerge gentoo-sources
        KV=$(emerge -s gentoo-sources | grep "Latest version installed" | cut -d: -f2 | tr -d '[:space:]')
        KERNEL=gentoo-sources-${KV}
        ln -sf $(ls -d /usr/src/linux*) /usr/src/linux
    else
        emerge =${KERNEL}
    fi
    [ "$?" != "0" ] && die "emerge failed on kernel sources."

    PKGDIR=$(source /etc/make.conf && echo $PKGDIR)
    KERNELPKG=${PKGDIR}/${KERNEL}-kernel.tar.bz2
    MODULESPKG=${PKGDIR}/${KERNEL}-modules.tar.bz2

    #GENKERNOPTS="--dmraid --evms --luks --lvm --arch-override=x86 --minkernpackage=${KERNELPKG} --modulespackage=${MODULESPKG}"
    GENKERNOPTS="--dmraid --luks --lvm --arch-override=x86 --minkernpackage=${KERNELPKG} --modulespackage=${MODULESPKG}"

    if [ "${USE_KERN_PKG}" == "yes" -a -e ${KERNELPKG}  -a  -e ${MODULESPKG} ]; then
        tar jxf ${KERNELPKG} -C /boot
        [ "$?" != "0" ] && die "unpacking of ${KERNELPKG} failed"
        tar jxf ${MODULESPKG} -C /
        [ "$?" != "0" ] && die "unpacking of ${MODULESPKG} failed"
        cp /boot/config* /usr/src/linux/.config
    else
        if [ "${KERNEL_CONF}" == "" ]; then
            genkernel ${GENKERNOPTS} all
            sed s/CONFIG_SQUASHFS=y/CONFIG_SQUASHFS=m/ -i /usr/src/linux/.config
            genkernel ${GENKERNOPTS} --no-clean all
        else
            genkernel ${GENKERNOPTS} --kernel-config=/etc/kernels/${KERNEL_CONF} all
        fi
        [ "$?" != "0" ] && die "Kernel compilation failed."
    fi

    modify_initramfs
}

function install_packages() {
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
        if [ "$p" == "gcc" -a  "${KEEP_CPP_SO}" == "yes" ]; then
            equery files gcc | grep -v "* Contents of " | grep -v "^/usr/lib/gcc/" | grep -v libstdc++ >> ~/clean.list
        else
            equery files $p | grep -v "* Contents of " >> ~/clean.list
        fi
    done
}

function clean_info() {
    clean_files "${PKGRMLIST}"
}

function place_at_desktop() {
    if [ -e /usr/share/applications/$1.desktop ]; then
        cp /usr/share/applications/$1.desktop /root/Desktop
    fi
}

function configure_system() {
    for s in `echo ${SERVICES}`; do
        rc-update add ${s} default
    done

    sed s/"# include"/include/ -i /etc/nanorc
    sed s/"\\\.sh"/"\\\.\(sh|cfg|conf|config|cnf|ini\)"/ -i /usr/share/nano/sh.nanorc

    mkdir -p /root/Desktop
    place_at_desktop gparted
    place_at_desktop lxterminal
    place_at_desktop xfce4-terminal
    place_at_desktop mozilla-firefox-3.5
    place_at_desktop mozilla-firefox-3.6
    place_at_desktop scite
}

function prepare() {
    env-update
    source /etc/profile
    build_makeconf
    #emerge -C device-mapper lvm2
    #emerge -C e2fsprogs e2fsprogs-libs
    #emerge e2fsprogs
}

#########################################################################
#                                                                       #
#  main                                                                 #
#                                                                       #
#########################################################################

prepare
useflags
build_kernel
install_packages
configure_system
clean_info

