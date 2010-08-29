#!/bin/sh

URL="http://de-mirror.org/distro/gentoo"
rm -rf index.html

# get latest snapshot
wget ${URL}/snapshots/
snapshot=`grep -o -E "portage-[[:digit:]]*.tar.lzma[^\.\"]" index.html | cut -d\< -f 1 | sort | tail -n 1`
rm -rf index.html
if [ ! -e $snapshot ]; then
    wget ${URL}/snapshots/$snapshot
fi

# get latest stage3
wget ${URL}/releases/x86/current-stage3/
stage3=`grep -o -E "stage3-i686-[[:digit:]]*.tar.bz2[^\.\"]" index.html | cut -d\< -f 1 | sort | tail -n 1`
rm -rf index.html
if [ ! -e $stage3 ]; then
    wget ${URL}/releases/x86/current-stage3/${stage3}
fi


