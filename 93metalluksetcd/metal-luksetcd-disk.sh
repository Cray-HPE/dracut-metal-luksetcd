#!/bin/sh

# DEVICES EXIST or DIE
[ -f /tmp/metaletcddisk.done ] && exit 0
ls /dev/sd* > /dev/null 2>&1 || exit 1

# SUBBROUTINES
type make_etcd > /dev/null 2>&1 || . /lib/metal-luksetcd-lib.sh
type metal_resolve_disk > /dev/null 2>&1 || . /lib/metal-lib.sh

# DISKS or RETRY
# Ignore whatever was selected for the overlay by starting +1 from that index.
disk_offset=$((${metal_disks:-2} + 1))
etcd="$(lsblk -l -o SIZE,NAME,TYPE,TRAN | grep -E '('"$metal_transports"')' | sort -u | awk '{print $1 "," $2}' | tail -n +${disk_offset} | tr '\n' ' ' | sed 's/ *$//')"
[ -z "${etcd}" ] && exit 1

# Find the right disk.
# 524288000000 is 0.5 TiB; required for this disk.
# exit 0 ; this module does not need to run on this node unless it meets the requirements.
export etcd_disk=$(metal_resolve_disk "$etcd" 524288000000) || exit 0

# Process the disk.
if [ "${metal_nowipe:-0}" = 0 ]; then
    [ ! -f /tmp/metaletcddisk.done ] && make_etcd "$etcd_disk"
fi
