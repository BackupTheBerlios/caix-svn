#!/bin/sh

source /root/livecd.conf

function die() {
    touch /error.occured
    exit 1
}

function squashfs_lzma_support() {
    s=$(readlink /usr/src/linux)
    KERNEL_VER=${s:6}

    if [ -e /tmp/squashfs-lzma ]; then
        puts "OK 1\n"
        cd /tmp/squashfs-lzma
        ./sqmake.sh ${KERNEL_VER}
        [ "$?" != "0" ] && die
    fi

    RAMFSDIR="/tmp/initramfs"

    mkdir -p ${RAMFSDIR}
    cd ${RAMFSDIR}
    gunzip < /boot/initramfs-genkernel-x86-${KERNEL_VER} | cpio -i -H newc
    mkdir -p ${RAMFSDIR}/lib/modules/${KERNEL_VER}/kernel/fs/squashfs/
    cp /lib/modules/${KERNEL_VER}/kernel/fs/squashfs/*.ko ${RAMFSDIR}/lib/modules/${KERNEL_VER}/kernel/fs/squashfs/

    if [ -e /tmp/squashfs-lzma ]; then
        echo unlzma >>${RAMFSDIR}/etc/modules/fs
        echo sqlzma >>${RAMFSDIR}/etc/modules/fs
    fi

    echo squashfs >>${RAMFSDIR}/etc/modules/fs
    find . | cpio -o -H newc | gzip > /boot/initramfs-genkernel-x86-${KERNEL_VER}
    cd /
}

env-update
source /etc/profile

#
# Build kernel first. Some packages depend on /usr/src/linux/.config
#
emerge -kuDN util-linux genkernel dmraid evms lvm2
[ "$?" != "0" ] && die
if [ "{KERNEL}" == "" ]; then
    emerge gentoo-sources
else
    emerge =${KERNEL}
fi
[ "$?" != "0" ] && die

genkernel --dmraid --evms --luks --lvm --kernel-config=/etc/kernels/${KERNEL_CONF} all
#genkernel --dmraid --evms --luks --lvm all
[ "$?" != "0" ] && die

squashfs_lzma_support

emerge -kuDN system
[ "$?" != "0" ] && die

emerge -kuDN world
[ "$?" != "0" ] && die

emerge -kuDN ${PKGLIST}
[ "$?" != "0" ] && die

revdep-rebuild
[ "$?" != "0" ] && die

echo -5 | etc-update

sed s/"# include"/include/ -i /etc/nanorc

#
# Now make a list of files to clean
#
function clean_files() {
    for p in $(echo $1); do
        equery files $p | grep -v "* Contents of " >> ~/clean.list
    done
}

clean_files "${PKGRMLIST}"

if [ "${NEED_CPP_SO}" == "yes" ]; then
    equery files gcc | grep -v "* Contents of " | grep -v "^/usr/lib/gcc/" | grep -v libstdc++ >> ~/clean.list
fi

for s in `echo ${SERVICES}`; do
    rc-update add ${s} default
done

