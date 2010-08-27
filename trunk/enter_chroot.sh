#!/bin/bash
#
# enter_chroot.sh   enter the CAIX build environment.
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
#!/bin/bash

LIVECD=$(pwd)
SRCDIR=${LIVECD}/source
TGTDIR=${LIVECD}/target

function ismounted() {
    [ "$(grep "^${1}" /proc/mounts)" = "" ]
}

user=`whoami`
if [ "${user}" != "root" ]; then
    echo "Error: superuser access is required to run this script."
    exit 1
fi

umount ${SRCDIR}/proc >/dev/null 2>/dev/null
umount ${SRCDIR}/dev  >/dev/null 2>/dev/null
umount ${SRCDIR}/sys  >/dev/null 2>/dev/null
#umount ${SRCDIR}/usr/portage/distfiles  >/dev/null 2>/dev/null
#umount ${SRCDIR}/usr/portage  >/dev/null 2>/dev/null

mount -t proc none ${SRCDIR}/proc
mount --bind /dev  ${SRCDIR}/dev
mount --bind /sys  ${SRCDIR}/sys
#mkdir -p ${SRCDIR}/usr/portage/distfiles
#mount --bind /usr/portage ${SRCDIR}/usr/portage

#DISTDIR=$(source /etc/make.conf; echo $DISTDIR)

#[ "${DISTDIR}" == "" ] && DISTDIR=/usr/portage/distfiles

#mount --bind ${DISTDIR} ${SRCDIR}/usr/portage/distfiles

#chroot ${SRCDIR} /root/build.sh
cp /etc/resolv.conf ${SRCDIR}/etc
chroot ${SRCDIR}

umount ${SRCDIR}/proc >/dev/null 2>/dev/null
umount ${SRCDIR}/dev  >/dev/null 2>/dev/null
umount ${SRCDIR}/sys  >/dev/null 2>/dev/null
#umount ${SRCDIR}/usr/portage/distfiles  >/dev/null 2>/dev/null
#umount ${SRCDIR}/usr/portage  >/dev/null 2>/dev/null
