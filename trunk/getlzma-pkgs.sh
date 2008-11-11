#!/bin/sh

packages="squashfs3.3.tar.gz lzma457.tar.bz2 sqlzma3.3-457-2.tar.bz2"
URL=http://www.squashfs-lzma.org/dl

for p in ${packages}; do
  wget ${URL}/${p} -O dist/${p}
  if [ "$?" != "0" ]; then
    echo "Error! Can not download ${p}"
    exit 1
  fi
done
