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
SQUASHFS_LZMA="yes"
SNAPSHOT=""

source "livecd.conf"

function usage() {
    echo ""
    echo "Usage: $0 -bhilnosv"
    echo ""
    echo "      Options are"
    echo ""
    echo "        -b <bootloader>        : Specify bootloader (grub|isolinux). Default is '${BOOTLOADER}'."
    echo "        -h                     : Show this help."
    echo "        -i <ISO creation>      : (yes|no). Default is 'yes'."
    echo "        -l <SquashFS lzma>     : Use LZMA compression for squashfs (yes|no). Default is '${SQUASHFS_LZMA}'."
    echo "        -n                     : Do not clean the source directory."
    echo "        -o <ISO name>          : Set the name for the created ISO. Default is '${ISONAME}'."
    echo "        -p <snapshot>          : Use a portage snapshot intead of mounting /usr/portage from host system."
    echo "        -s <SquashFS creation> : (yes|no). Default is 'yes'."
    echo "        -t <stage>             : Specify stage3-file."
    echo "        -v <volid>             : Set the volume id of the CD/DVD. Default is '${VOLID}'."
    echo ""
    exit 1
}

while getopts ":bi:l:hnop:s:t:v:" Option; do
    case ${Option} in
        b) BOOTLOADER=${OPTARG}
           if [ "${BOOTLOADER}" != "grub" -a  "${BOOTLOADER}" != "isolinux" ]; then
               usage
           fi;;
        h) usage;;
        i) CREATE_ISO=${OPTARG}
           if [ "${CREATE_ISO}" != "no" -a  "${CREATE_ISO}" != "yes" ]; then
               usage
           fi;;
        l) SQUASHFS_LZMA=${OPTARG}
           if [ "${SQUASHFS_LZMA}" != "no" -a  "${SQUASHFS_LZMA}" != "yes" ]; then
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

function die() {
    echo -e "\nError: $1\n\n"
    unmount_all
    exit 1
}

function check_error() {
    [ "$?" != "0" ] && die $1
}

function safe_mount() {
    local mntpnts=`mount | awk '{print $3}'`
    [ "`echo ${mntpnts} | grep $2`" != "$2" ] && mount --bind $1 $2
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

    msg="unpacking $1"
    if [ "$2" != "" ]; then
        msg="${msg} to $2"
    fi

    echo ${msg}

    fparts=$(echo | basename $1 | sed s/"\."/" "/g)
    afparts=($fparts)
    n=${#afparts[@]}
    ext=${afparts[$((n-1))]}

    if [ "$2" == "" ]; then
        TDIR=""
    else
        TDIR=" -C $2 "
    fi

    case $ext in
        "bz2") tar jxf $1 ${TDIR};;
        "gz") tar zxf $1 ${TDIR};;
        "lzma") lzma -cd $1 | tar xf - ${TDIR};;
        "tar") tar xf $1 ${TDIR};;
        *) echo "$1 has the unknown extension ${ext}"
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
    DISTDIR=$(source /etc/make.conf; echo $DISTDIR)
    [ "$DISTDIR" == "" ] && DISTDIR=/usr/portage/distfiles

    mkdir -p ${SOURCEDIR}/usr/portage/distfiles

    safe_mount $DISTDIR ${SOURCEDIR}/usr/portage/distfiles

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

    if [ "${SQUASHFS_LZMA}" == "yes" ]; then
        [ -e ${ARCHIVEDIR}/${SQLZMA} ] || die "missing ${ARCHIVEDIR}/${SQLZMA}"
        [ -e ${ARCHIVEDIR}/${LZMASDK} ] || die "missing ${ARCHIVEDIR}/${LZMASDK}"
        [ -e ${ARCHIVEDIR}/${SQFSTOOLS} ] || die "missing ${ARCHIVEDIR}/${SQFSTOOLS}"
        [ -e ${ARCHIVEDIR}/sqcompile.sh ] || die "missing ${ARCHIVEDIR}/sqcompile.sh"
        [ -e ${ARCHIVEDIR}/sqmakefile.patch ] || die "missing ${ARCHIVEDIR}/sqmakefile.patch"

        mkdir -p ${SOURCEDIR}/tmp/squashfs-lzma
        unpack ${ARCHIVEDIR}/${SQLZMA} ${SOURCEDIR}/tmp/squashfs-lzma
        unpack ${ARCHIVEDIR}/${SQFSTOOLS} ${SOURCEDIR}/tmp/squashfs-lzma
        mkdir -p ${SOURCEDIR}/tmp/squashfs-lzma/lzmasdk
        unpack ${ARCHIVEDIR}/${LZMASDK} ${SOURCEDIR}/tmp/squashfs-lzma/lzmasdk
        cp ${ARCHIVEDIR}/sqcompile.sh ${SOURCEDIR}/tmp/squashfs-lzma
        cp ${ARCHIVEDIR}/sqmakefile.patch ${SOURCEDIR}/tmp/squashfs-lzma
    fi

    cp /etc/resolv.conf ${SOURCEDIR}/etc
    cp chroot_build.sh ${SOURCEDIR}/root
    chmod +x ${SOURCEDIR}/root/chroot_build.sh
    cp livecd.conf ${SOURCEDIR}/root

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
    rsync --delete-after --delete-excluded --archive --hard-links \
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
    [ -e ${WORKDIR}/isolinux/isolinux.bin ] || cp ${SOURCEDIR}/usr/lib/syslinux/isolinux.bin \
                                               ${WORKDIR}/isolinux
    [ -e ${WORKDIR}/bin/mksquashfs ] || cp ${SOURCEDIR}/tmp/squashfs-lzma/squashfs3.3/squashfs-tools/mksquashfs \
                                        ${WORKDIR}/bin/
    [ -e ${WORKDIR}/bin/unsquashfs ] || cp ${SOURCEDIR}/tmp/squashfs-lzma/squashfs3.3/squashfs-tools/unsquashfs \
                                        ${WORKDIR}/bin/

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
        elif [ -L ${TGTFILES}/${i} ]; then
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
    rm -f ${TARGETDIR}/livecd.squashfs
    if [ "${SQUASHFS_LZMA}" == "yes" ]; then
        ${WORKDIR}/bin/mksquashfs ${TGTFILES}/ ${TARGETDIR}/livecd.squashfs -noappend
    else
        ${WORKDIR}/bin/mksquashfs ${TGTFILES}/ ${TARGETDIR}/livecd.squashfs -noappend -nolzma
    fi
}

function create_iso () {
    ##############################################################################
    #                                                                            #
    #    prepare ISO target                                                      #
    #                                                                            #
    ##############################################################################
    if [ "${BOOTLOADER}" == "isolinux" ]; then
        rsync -a --exclude ".svn" --exclude ".svn/*" ${WORKDIR}/isolinux ${TARGETDIR}

        cp ${SOURCEDIR}/boot/kernel-genkernel-x86* ${TARGETDIR}/isolinux/vmlinuz
        cp ${SOURCEDIR}/boot/initramfs-genkernel-x86* ${TARGETDIR}/isolinux/initrd.igz
        #cp /boot/memtest86plus/memtest.bin ${TARGETDIR}/isolinux
    else
        rsync -a --exclude ".svn" --exclude ".svn/*" ${SOURCEDIR}/boot ${TARGETDIR}
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

##############################################################################
#                                                                            #
#    main                                                                    #
#                                                                            #
##############################################################################
[ -e "${WORKDIR}/create_livecd.sh" ] || die "You must run 'create_livecd.sh' in its directory"
[ -e "${WORKDIR}/livecd.conf" ] || die "Missing 'livecd.conf'"
source ${WORKDIR}/livecd.conf

[ "${CLEAN_SOURCE}" == "yes" ] && build_source
[ "${CREATE_SQUASH}" == "yes" ] && create_squashfs
[ "${CREATE_ISO}" == "yes" ] && create_iso
