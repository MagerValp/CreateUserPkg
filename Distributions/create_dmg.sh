#!/bin/bash

srcdir="$1"

if [ -z "$srcdir" ]; then
    echo "Usage: $0 srcdir"
    exit 1
fi

find "$srcdir" -name .DS_Store -print0 | xargs -0 rm -f

dmg_fname="$srcdir.dmg"

printf "\nCreating image\n"
sudo -p "Password for %p@%h: " hdiutil create -srcfolder "$srcdir" -uid 0 -gid 0 -ov "$dmg_fname"
sudo -p "Password for %p@%h: " chown ${UID} "$dmg_fname"
