#!/bin/bash

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

    mkdir -p ${SOURCEDIR}/usr/portage/distfiles
    echo "SNAPSHOT: ${SNAPSHOT}"
    if [ "${SNAPSHOT}" == "" ]; then
        safe_mount /usr/portage ${SOURCEDIR}/usr/portage
    else
        [ -e ${SNAPSHOT} ] || die "${SNAPSHOT} does not exist"
        unpack ${SNAPSHOT} ${SOURCEDIR}/usr
    fi
    DISTDIR=$(source /etc/make.conf; echo $DISTDIR)
    [ "$DISTDIR" == "" ] && DISTDIR=/usr/portage/distfiles

    safe_mount $DISTDIR ${SOURCEDIR}/usr/portage/distfiles

    ##############################################################################
    #                                                                            #
    #    copy extra files                                                        #
    #                                                                            #
    ##############################################################################
    rsync -a ${WORKDIR}/extra/ ${SOURCEDIR}/

    if [ "${SQUASHFS_LZMA}" == "yes" ]; then
        [ -e ${ARCHIVEDIR}/${SQLZMA} ] || die "missing ${ARCHIVEDIR}/${SQLZMA}"
        [ -e ${ARCHIVEDIR}/${LZMASDK} ] || die "missing ${ARCHIVEDIR}/${LZMASDK}"
        [ -e ${ARCHIVEDIR}/${SQFSTOOLS} ] || die "missing ${ARCHIVEDIR}/${SQFSTOOLS}"
        [ -e ${ARCHIVEDIR}/sqlzma-extra.tar.lzma ] || die "missing ${ARCHIVEDIR}/sqlzma-extra.tar.lzma"

        mkdir -p ${SOURCEDIR}/tmp/squashfs-lzma
        unpack ${ARCHIVEDIR}/${SQLZMA} ${SOURCEDIR}/tmp/squashfs-lzma
        unpack ${ARCHIVEDIR}/${SQFSTOOLS} ${SOURCEDIR}/tmp/squashfs-lzma
        unpack ${ARCHIVEDIR}/sqlzma-extra.tar.lzma ${SOURCEDIR}/tmp/squashfs-lzma
        mkdir -p ${SOURCEDIR}/tmp/squashfs-lzma/lzmasdk
        unpack ${ARCHIVEDIR}/${LZMASDK} ${SOURCEDIR}/tmp/squashfs-lzma/lzmasdk

        pushd .
        cd ${SOURCEDIR}/tmp/squashfs-lzma/lzmasdk
        patch -p1 <../sqlzma1-449.patch
        cd ${SOURCEDIR}/tmp/squashfs-lzma/squashfs3.3
        patch -p1 <../sqlzma2u-3.3.patch
        popd
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

    [ -e ${SOURCEDIR}/error.occured ] && die "something went wrong in chroot-environment"

    rsync -a ${WORKDIR}/extra/ ${SOURCEDIR}/
}

function check_squashfs_lzma() {
    mksquashfs 2>&1 | grep -qs lzma
    if [ "$?" == "0" ]; then
        true
    else
        false
    fi
}

function create_squashfs() {
    empty_dir ${TARGETDIR}
    mkdir -p ${TARGETDIR}/files

    ##############################################################################
    #                                                                            #
    #    copy parts of the build environment to the squashfs target              #
    #                                                                            #
    ##############################################################################

    echo "copying ${SOURCEDIR} to ${TARGETDIR}/files"
    rsync --delete-after --delete-excluded --archive --hard-links \
          --exclude "tmp/*" --exclude "var/tmp/*" --exclude "var/cache/*" \
          --exclude "*.h" --exclude "*.a" --exclude "*.la" --exclude ".keep*" \
          --exclude "usr/portage" --exclude "etc/portage" \
          --exclude "usr/share/doc" --exclude "var/db" --exclude "usr/src" \
          --exclude "usr/include" --exclude "usr/lib/pkgconfig" \
          --exclude "proc/*" --exclude "sys/*" --exclude "root/chroot_build.sh" \
          --exclude "etc/kernels" \
          ${SOURCEDIR}/ ${TARGETDIR}/files/

    ##############################################################################
    #                                                                            #
    #    clean the squashfs target                                               #
    #                                                                            #
    ##############################################################################
    echo "cleaning ${TARGETDIR}/files"
    for d in `echo ${DIRS_TO_REMOVE}`; do
        rm -rf ${TARGETDIR}/files/${d}
    done
    rm -f ${TARGETDIR}/files/etc/mtab
    touch ${TARGETDIR}/files/etc/mtab
    rm -f ${TARGETDIR}/files/root/.bash_history
    mkdir -p ${TARGETDIR}/files/var/log
    mkdir -p ${TARGETDIR}/files/var/lib/dhcp

    dirlist=""
    for i in `cat ${SOURCEDIR}/root/clean.list`; do
        if [ -f ${TARGETDIR}/files/${i} ]; then
            rm -f ${TARGETDIR}/files/${i}
        elif [ -L ${TARGETDIR}/files/${i} ]; then
            rm -f ${TARGETDIR}/files/${i}
        elif [ -d ${TARGETDIR}/files/${i} ]; then
            dirlist="${dirlist} ${TARGETDIR}/files/${i}"
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

    rm ${TARGETDIR}/files/root/clean.list
    rm ${TARGETDIR}/files/root/livecd.conf
    mkdir -p ${TARGETDIR}/files/var/log

    ##############################################################################
    #                                                                            #
    #    creating the squashfs image                                             #
    #                                                                            #
    ##############################################################################
    rm -f ${TARGETDIR}/livecd.squashfs
    if [ "${SQUASHFS_LZMA}" == "yes" ]; then
        check_squashfs_lzma || die "mksquashfs does not support lzma. Please install a new version"
        mksquashfs ${TARGETDIR}/files/ ${TARGETDIR}/livecd.squashfs -noappend
    else
        soptions="-noappend"
        if check_squashfs_lzma; then
            soptions="${soptions} -nolzma"
        fi
        mksquashfs ${TARGETDIR}/files/ ${TARGETDIR}/livecd.squashfs ${soptions}
    fi
}

function create_iso () {
    ##############################################################################
    #                                                                            #
    #    prepare ISO target                                                      #
    #                                                                            #
    ##############################################################################
    if [ "${BOOTLOADER}" == "isolinux" ]; then
        rsync -av ${WORKDIR}/isolinux ${TARGETDIR}
        cp /usr/lib/syslinux/isolinux.bin ${TARGETDIR}/isolinux
        cp ${SOURCEDIR}/boot/kernel-genkernel-x86* ${TARGETDIR}/isolinux/vmlinuz
        cp ${SOURCEDIR}/boot/initramfs-genkernel-x86* ${TARGETDIR}/isolinux/initrd.igz
        cp /boot/memtest86plus/memtest.bin ${TARGETDIR}/isolinux
    else
        rsync -av ${SOURCEDIR}/boot ${TARGETDIR}
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

if check_squashfs_lzma && [ "SQUASHFS_LZMA" == "yes" ]; then
    die "mksquashfs does not support lzma. Please disable with -l option or install a suitable squashfs utils."
fi

[ "${CLEAN_SOURCE}" == "yes" ] && build_source
[ "${CREATE_SQUASH}" == "yes" ] && create_squashfs
[ "${CREATE_ISO}" == "yes" ] && create_iso
