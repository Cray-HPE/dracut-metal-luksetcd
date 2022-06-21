#!/bin/bash
#
# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# metal-luksetcd-disk.sh
[ "${metal_debug:-0}" = 0 ] || set -x

# Wait for disks to exist.
command -v disks_exist > /dev/null 2>&1 || . /lib/metal-lib.sh
disks_exist || exit 1

# Now that disks exist it's worthwhile to load the library.
command -v make_etcd > /dev/null 2>&1 || . /lib/metal-luksetcd-lib.sh

# Wait for the pave function to wipe the disks if the wipe is enabled.
metal_paved || exit 1

# Check if our filesystem already exists.
etcd_disk=$(scan_etcd)

# Create the ETCD disk if it didn't exist.
if [ -z "$etcd_disk" ]; then
    
    # Offset the search by the number of disks used up by the main metal dracut module.
    disk_offset=$((${metal_disks:-2} + 1))
    etcd="$(metal_scand $disk_offset)"
    
    # If no disks were found, die.
    # When rd.luks is enabled, this hook-script expects to find a disk. Die if one isn't found.
    if [ -z "${etcd}" ]; then
        metal_luksetcd_die "No disks were found for ETCD"
        exit 1
    fi
    
    # Find a disk that is at least as big as $metal_disk_small.
    etcd_disk=$(metal_resolve_disk "$etcd" $metal_disk_small)
    echo >&2 "Found the following disk for etcd LUKS: $etcd_disk"
    
    # Make the etcd disk.
    make_etcd "$etcd_disk"
else
    echo 0 > $ETCD_DONE_FILE
fi

# If our disk was created or unlocked, satisfy the wait_for_dev hook.
if [ -f $ETCD_DONE_FILE ]; then
    ln -s null /dev/metal-luks
    exit 0
fi
