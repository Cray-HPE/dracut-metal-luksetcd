#!/bin/bash

# DEVICES EXIST or DIE
[ -f /tmp/metaletcddisk.done ] && exit 0
ls /dev/sd* > /dev/null 2>&1 || exit 1

# SUBBROUTINES
type make_etcd > /dev/null 2>&1 || . /lib/metal-luksetcd-lib.sh
type metal_resolve_disk > /dev/null 2>&1 || . /lib/metal-lib.sh

# DISKS or RETRY
# Ignore whatever was selected for the overlay by starting +1 from that index.
# MAINTAINER NOTE: Regardless of gcp mode, this will ignore any NVME partition incase they stick around after wiping.
disk_offset=$((${metal_disks:-2} + 1))
etcd="$(metal_scand $disk_offset)"
[ -z "${etcd}" ] && exit 1

# Find the right disk.
# 524288000000 is 0.5 TiB; required for this disk.
# exit 0 ; this module does not need to run on this node unless it meets the requirements.
export etcd_disk=$(metal_resolve_disk "$etcd" $metal_disk_small) || exit 0

# Process the disk.
if [ "${metal_nowipe:-0}" = 0 ]; then
    [ ! -f /tmp/metaletcddisk.done ] && make_etcd "$etcd_disk"
fi
