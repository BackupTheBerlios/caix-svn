#!/bin/bash
#
# create_livecd.sh   ISO image creation tool.
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

d=`date +%Y%m%d`

WORKDIR=`pwd`
SOURCEDIR=${WORKDIR}/source
TARGETDIR=${WORKDIR}/target
ARCHIVEDIR=${WORKDIR}/dist
STAGE=${ARCHIVEDIR}/stage3-x86-2008.0.tar.bz2

VOLID="LiveCD"
ISONAME="livecd"
BOOTLOADER="isolinux"
CLEAN_SOURCE="yes"
CREATE_SQUASH="yes"
CREATE_ISO="yes"
CREATE_ARCHIVE="no"
USE_KERN_PKG="yes"
SNAPSHOT=""
DEVICETYPE="CD"
LIVETYPE="livecd"

source "livecd.conf"

function usage() {
    echo ""
    echo "Usage: $0 -bdhinosv"
    echo ""
    echo "      Options are"
    echo ""
    echo "        -b <bootloader>        : Specify bootloader (grub|isolinux|syslinux). Default is '${BOOTLOADER}'."
    echo "        -d <device type>       : Specify the device (CD|USB). Default is '${DEVICETYPE}'."
    echo "        -h                     : Show this help."
    echo "        -i <ISO creation>      : (yes|no). Default is '${CREATE_ISO}'."
    echo "        -k <kernel package>    : (yes|no). Use a compiled kernel from a previous run. Default is '${USE_KERN_PKG}'."
    echo "        -n                     : Do not clean the source directory."
    echo "        -o <ISO name>          : Set the name for the created ISO. Default is '${ISONAME}'."
    echo "        -p <snapshot>          : Use a portage snapshot intead of mounting /usr/portage from host system."
    echo "        -s <SquashFS creation> : (yes|no). Default is 'yes'."
    echo "        -t <stage>             : Specify stage3-file."
    echo "        -v <volid>             : Set the volume id of the CD/DVD. Default is '${VOLID}'."
    echo ""
    exit 1
}

while getopts ":bd:i:k:l:hnop:s:t:v:" Option; do
    case ${Option} in
        b) BOOTLOADER=${OPTARG}
           if [ "${BOOTLOADER}" != "grub" -a  "${BOOTLOADER}" != "isolinux" -a "${BOOTLOADER}" != "syslinux" ]; then
               usage
           fi;;
        d) DEVICETYPE=${OPTARG}
           if [ "${DEVICETYPE}" != "CD" -a  "${DEVICETYPE}" != "USB" ]; then
               usage
           fi
           if [ "${DEVICETYPE}" = "CD" -a "${BOOTLOADER}" = "syslinux" ]; then
               BOOTLOADER="isolinux"
           fi
           if [ "${DEVICETYPE}" = "USB" -a "${BOOTLOADER}" = "isolinux" ]; then
               BOOTLOADER="syslinux"
           fi;;
        h) usage;;
        i) CREATE_ISO=${OPTARG}
           if [ "${CREATE_ISO}" != "no" -a  "${CREATE_ISO}" != "yes" ]; then
               usage
           fi;;
        k) USE_KERN_PKG=${OPTARG}
           if [ "${USE_KERN_PKG}" != "no" -a  "${USE_KERN_PKG}" != "yes" ]; then
               usage
           fi;;
        n) CLEAN_SOURCE="no";;
        o) ISONAME=${OPTARG};;
        p) SNAPSHOT=${OPTARG};;
        s) CREATE_SQUASH=${OPTARG}
           if [ "${CREATE_SQUASH}" != "no" -a  "${CREATE_SQUASH}" != "yes" ]; then
               usage
           fi;;
        t) STAGE=${OPTARG};;
        v) VOLID=${OPTARG};;
        *) usage;;
    esac
done

function die() {
    echo -e "\nError: ${1}\n\n"
    unmount_all
    exit 1
}

function check_error() {
    [ "$?" != "0" ] && die ${1}
}

function check_prog() {
    local path=`which ${1} 2>/dev/null`
    if [ "${path}" != "" ]; then
        true
    else
        false
    fi
}

function unmount_all() {
    umount ${SOURCEDIR}/proc >/dev/null 2>/dev/null
    umount ${SOURCEDIR}/dev >/dev/null 2>/dev/null
    umount ${SOURCEDIR}/sys >/dev/null 2>/dev/null
    umount ${SOURCEDIR}/usr/portage/distfiles >/dev/null 2>/dev/null
    if [ "${SNAPSHOT}" == "" ]; then
        umount ${SOURCEDIR}/usr/portage >/dev/null 2>/dev/null
    fi
    umount ${SOURCEDIR}/packages >/dev/null 2>/dev/null
}

function safe_mount() {
    local mntpnts=`mount | awk '{print $3}'`
    [ "`echo ${mntpnts} | grep $2`" != "$2" ] && mount --bind ${1} $2
}

function empty_dir() {
    if [ -d ${1} ]; then
        echo "removing ${1}"
        rm -rf ${1}
    fi
    mkdir -p ${1}
}

function unpack() {
    [ ! -e ${1} ] && die "${1} does not exist"

    local msg="unpacking ${1}"
    if [ "$2" != "" ]; then
        msg="${msg} to $2"
    fi

    echo ${msg}

    local fparts=$(echo | basename ${1} | sed s/"\."/" "/g)
    local afparts=($fparts)
    local n=${#afparts[@]}
    local ext=${afparts[$((n-1))]}

    if [ "$2" == "" ]; then
        TDIR=""
    else
        TDIR=" -C $2 "
    fi

    case ${ext} in
        "lzma"|"xz"|"7z") if ! (check_prog ${ext}); then
                               echo "Program ${ext} not found. Please install."
                               exit 1
                          fi;;
        *) echo "${1} has the unknown extension ${ext}"
           exit 1;;
    esac

    case ${ext} in
        "bz2") tar jxf ${1} ${TDIR};;
        "tbz2") tar jxf ${1} ${TDIR};;
        "gz") tar zxf ${1} ${TDIR};;
        "tgz") tar zxf ${1} ${TDIR};;
        "lzma") lzma -cd ${1} | tar xf - ${TDIR};;
        "xz") xz -cd ${1} | tar xf - ${TDIR};;
        "7z") 7z -x ${1} -so | tar xf - ${TDIR};;
        "tar") tar xf ${1} ${TDIR};;
        *) echo "${1} has the unknown extension ${ext}"
           exit 1;;
    esac
    check_error ${msg}
}

function build_source() {
    unmount_all

    [ -e "${WORKDIR}/packages" ] || mkdir -p "${WORKDIR}/packages"

    empty_dir ${SOURCEDIR}

    ##############################################################################
    #                                                                            #
    #    unpacking stage3                                                        #
    #                                                                            #
    ##############################################################################
    unpack ${STAGE} ${SOURCEDIR}

    ##############################################################################
    #                                                                            #
    #    mount a few necessary directories                                       #
    #                                                                            #
    ##############################################################################
    mkdir -p ${SOURCEDIR}/packages
    mount --bind ${WORKDIR}/packages ${SOURCEDIR}/packages
    safe_mount /proc ${SOURCEDIR}/proc
    safe_mount /dev ${SOURCEDIR}/dev
    safe_mount /sys ${SOURCEDIR}/sys

    mkdir -p ${SOURCEDIR}/usr/portage

    if [ "${SNAPSHOT}" == "" ]; then
        safe_mount /usr/portage ${SOURCEDIR}/usr/portage
    else
        [ -e ${SNAPSHOT} ] || die "${SNAPSHOT} does not exist"
        unpack ${SNAPSHOT} ${SOURCEDIR}/usr
    fi
    DISTDIR=$(source /etc/make.conf; echo ${DISTDIR})
    [ "$DISTDIR" == "" ] && DISTDIR=/usr/portage/distfiles

    mkdir -p ${DISTDIR}
    mkdir -p ${SOURCEDIR}/usr/portage/distfiles

    safe_mount ${DISTDIR} ${SOURCEDIR}/usr/portage/distfiles

    ##############################################################################
    #                                                                            #
    #    copy extra files                                                        #
    #                                                                            #
    ##############################################################################
    rsync -a --exclude ".svn" --exclude ".svn/*" ${WORKDIR}/extra/ ${SOURCEDIR}/

    if [ "${KERNEL}" != "" ]; then
      echo "<sys-kernel/${KERNEL}" >> ${SOURCEDIR}/etc/portage/package.mask
      echo ">sys-kernel/${KERNEL}" >> ${SOURCEDIR}/etc/portage/package.mask
    fi

    cp /etc/resolv.conf ${SOURCEDIR}/etc
    cp chroot_build.sh ${SOURCEDIR}/root
    chmod +x ${SOURCEDIR}/root/chroot_build.sh
    cp livecd.conf ${SOURCEDIR}/root
    echo USE_KERN_PKG=${USE_KERN_PKG} >> ${SOURCEDIR}/root/livecd.conf

    ##############################################################################
    #                                                                            #
    #    compile livecd system                                                   #
    #                                                                            #
    ##############################################################################
    chroot ${SOURCEDIR} /root/chroot_build.sh
    unmount_all

    if [ -e ${SOURCEDIR}/error.occured ]; then
       msg=$(cat ${SOURCEDIR}/error.occured)
       die "(chroot environment) ${msg}"
    fi

    rsync -a --exclude ".svn" --exclude ".svn/*" ${WORKDIR}/extra/ ${SOURCEDIR}/
}


function create_squashfs() {
    empty_dir ${TARGETDIR}
    TGTFILES=${TARGETDIR}/files

    mkdir -p ${TGTFILES}

    ##############################################################################
    #                                                                            #
    #    copy parts of the build environment to the squashfs target              #
    #                                                                            #
    ##############################################################################

    echo "copying ${SOURCEDIR} to ${TGTFILES}"
    rsync --delete-after --delete-excluded --archive --hard-links --links \
          --exclude "tmp/*" --exclude "var/tmp/*" --exclude "var/cache/*" \
          --exclude "*.h" --exclude "*.a" --exclude "*.la" --exclude ".keep*" \
          --exclude "usr/portage" --exclude "etc/portage" \
          --exclude "usr/share/doc" --exclude "var/db" --exclude "usr/src" \
          --exclude "usr/include" --exclude "usr/lib/pkgconfig" \
          --exclude "proc/*" --exclude "sys/*" --exclude "root/chroot_build.sh" \
          --exclude "etc/kernels" --exclude ".svn" --exclude ".svn/*" \
          ${SOURCEDIR}/ ${TGTFILES}/

    ##############################################################################
    #                                                                            #
    #    copy utilities to the build environment                                 #
    #                                                                            #
    ##############################################################################
    mkdir -p ${WORKDIR}/bin
    cp ${SOURCEDIR}/usr/share/syslinux/isolinux.bin ${WORKDIR}/isolinux

    ##############################################################################
    #                                                                            #
    #    clean the squashfs target                                               #
    #                                                                            #
    ##############################################################################
    echo "cleaning ${TGTFILES}"
    for d in `echo ${DIRS_TO_REMOVE}`; do
        rm -rf ${TGTFILES}/${d}
    done
    rm -f ${TGTFILES}/etc/mtab
    touch ${TGTFILES}/etc/mtab
    rm -f ${TGTFILES}/root/.bash_history
    mkdir -p ${TGTFILES}/var/log
    mkdir -p ${TGTFILES}/var/lib/dhcp

    dirlist=""
    for i in `cat ${SOURCEDIR}/root/clean.list`; do
        if [ -f ${TGTFILES}/${i} ]; then
            rm -f ${TGTFILES}/${i}
        elif [ -d ${TGTFILES}/${i} ]; then
            dirlist="${dirlist} ${TGTFILES}/${i}"
        fi
    done

    flag=0
    while [ "${flag}" == "0" ]; do
        flag=1
        for d in `echo ${dirlist}`; do
            rmdir ${d} >/dev/null 2>/dev/null
            [ "$?" == "0" ] && flag=0
        done
    done

    rm ${TGTFILES}/root/clean.list
    rm ${TGTFILES}/root/livecd.conf

    #
    # remove broken links
    #
    symlinks=$(find ${TGTFILES} -type l)
    for l in ${symlinks}; do
        x=$(readlink -e ${l})
        if [ "${x}" == "" ]; then
           y=$(readlink ${l})
           x="${TGTFILES}${y}"
        fi
        [ -e ${x} ] || rm -f ${l}
    done

    mkdir -p ${TGTFILES}/var/log

    ##############################################################################
    #                                                                            #
    #    creating the squashfs image                                             #
    #                                                                            #
    ##############################################################################
    rm -f ${TARGETDIR}/${LIVETYPE}.squashfs
    mksquashfs ${TGTFILES}/ ${TARGETDIR}/${LIVETYPE}.squashfs -noappend
}

function create_iso () {
    ##############################################################################
    #                                                                            #
    #    prepare ISO target                                                      #
    #                                                                            #
    ##############################################################################
    if [ "${BOOTLOADER}" == "isolinux" ]; then
        rsync -a --exclude ".svn" --exclude ".svn/*" ${WORKDIR}/isolinux ${TARGETDIR}

        cp ${SOURCEDIR}/boot/kernel-* ${TARGETDIR}/isolinux/vmlinuz
        cp ${SOURCEDIR}/boot/initramfs-* ${TARGETDIR}/isolinux/initrd.igz
        #cp /boot/memtest86plus/memtest.bin ${TARGETDIR}/isolinux
    else
        rsync -a --exclude ".svn" --exclude ".svn/*" ${SOURCEDIR}/boot ${TARGETDIR}
    fi

    if [ -d "${WORKDIR}/data" ]; then
        rsync -a --exclude ".svn" --exclude ".svn/*" ${WORKDIR}/data ${TARGETDIR}
    fi

    touch ${TARGETDIR}/livecd

    ##############################################################################
    #                                                                            #
    #    building the ISO-image                                                  #
    #                                                                            #
    ##############################################################################

    if [ "$BOOTLOADER" == "isolinux" ]; then
        mkisofs -J -R -l -V ${VOLID} -o ${WORKDIR}/${ISONAME}.iso -b isolinux/isolinux.bin -c isolinux/boot.cat \
   	        -no-emul-boot -boot-load-size 4 -boot-info-table -m ${TARGETDIR}/files ${TARGETDIR}
    else
        mkisofs -J -R -V ${VOLID} -b boot/grub/stage2_eltorito -no-emul-boot -boot-load-size 4 -boot-info-table -iso-level 4 \
                -hide-rr-moved -c boot.catalog -o ${WORKDIR}/${ISONAME}.iso -x files ${TARGETDIR}
    fi
}

function create_archive () {
    ##############################################################################
    #                                                                            #
    #    prepare ISO target                                                      #
    #                                                                            #
    ##############################################################################
    if [ "${BOOTLOADER}" == "isolinux" -o "${BOOTLOADER}" == "syslinux" ]; then
        rsync -a --exclude ".svn" --exclude ".svn/*" ${WORKDIR}/${BOOTLOADER} ${TARGETDIR}

        cp ${SOURCEDIR}/boot/kernel-* ${TARGETDIR}/${BOOTLOADER}/vmlinuz
        cp ${SOURCEDIR}/boot/initramfs-* ${TARGETDIR}/${BOOTLOADER}/initrd.igz
    else
        rsync -a --exclude ".svn" --exclude ".svn/*" ${SOURCEDIR}/boot ${TARGETDIR}
    fi

    if [ -d "${WORKDIR}/data" ]; then
        rsync -a --exclude ".svn" --exclude ".svn/*" ${WORKDIR}/data ${TARGETDIR}
    fi

    touch ${TARGETDIR}/${LIVETYPE}

    ##############################################################################
    #                                                                            #
    #    building the archive                                                    #
    #                                                                            #
    ##############################################################################

    tar -C ${TARGETDIR} -cjf ${LIVETYPE}.tar.bz2 . --exclude files
}

##############################################################################
#                                                                            #
#    main                                                                    #
#                                                                            #
##############################################################################

user=`whoami`
[ "${user}" == "root" ] || die "You must be root to run this script"

[ -e "${WORKDIR}/create_livecd.sh" ] || die "You must run 'create_livecd.sh' in its directory"
[ -e "${WORKDIR}/livecd.conf" ] || die "Missing 'livecd.conf'"
source ${WORKDIR}/livecd.conf

[ "${DEVICETYPE}" == "CD" ] && LIVETYPE="livecd"
[ "${DEVICETYPE}" == "USB" ] && LIVETYPE="liveusb"
[ "${CLEAN_SOURCE}" == "yes" ] && build_source
[ "${CREATE_SQUASH}" == "yes" ] && create_squashfs
[ "${CREATE_ISO}" == "yes" ] && create_iso
[ "${CREATE_ARCHIVE}" == "yes" ] && create_archive
