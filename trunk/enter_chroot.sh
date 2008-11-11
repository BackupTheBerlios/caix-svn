#!/bin/bash

LIVECD=$(pwd)
SRCDIR=${LIVECD}/source
TGTDIR=${LIVECD}/target

function ismounted() {
    [ "$(grep "^${1}" /proc/mounts)" = "" ]
}

umount ${SRCDIR}/proc >/dev/null 2>/dev/null
umount ${SRCDIR}/dev  >/dev/null 2>/dev/null
umount ${SRCDIR}/sys  >/dev/null 2>/dev/null
umount ${SRCDIR}/usr/portage/distfiles  >/dev/null 2>/dev/null
umount ${SRCDIR}/usr/portage  >/dev/null 2>/dev/null

mount -t proc none ${SRCDIR}/proc
mount --bind /dev  ${SRCDIR}/dev
mount --bind /sys  ${SRCDIR}/sys
mkdir -p ${SRCDIR}/usr/portage/distfiles
mount --bind /usr/portage ${SRCDIR}/usr/portage

DISTDIR=$(source /etc/make.conf; echo $DISTDIR)

[ "${DISTDIR}" == "" ] && DISTDIR=/usr/portage/distfiles

mount --bind ${DISTDIR} ${SRCDIR}/usr/portage/distfiles

#chroot ${SRCDIR} /root/build.sh
cp /etc/resolv.conf ${SRCDIR}/etc
chroot ${SRCDIR}

umount ${SRCDIR}/proc >/dev/null 2>/dev/null
umount ${SRCDIR}/dev  >/dev/null 2>/dev/null
umount ${SRCDIR}/sys  >/dev/null 2>/dev/null
umount ${SRCDIR}/usr/portage/distfiles  >/dev/null 2>/dev/null
umount ${SRCDIR}/usr/portage  >/dev/null 2>/dev/null
