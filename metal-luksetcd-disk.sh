#!/bin/sh

# DEVICES EXIST or DIE
[ -f /tmp/metaletcddisk.done ] && exit 0
ls /dev/sd* > /dev/null 2>&1 || exit 1

# SUBBROUTINES
type make_etcd > /dev/null 2>&1 || . /lib/metal-luksetcd-lib.sh

# DISKS or RETRY
# Ignore whatever was selected for the overlay by starting +1 from that index.
disk_index=$((${metal_disks:-2} + 1))
etcd="$(lsblk -b -l -o SIZE,NAME,TYPE,TRAN | grep -E '(sata|nvme)' | sort -h | awk '{print $1 " " $2}' | tail -n +${disk_index} | tr '\n' ' ')"
[ -z "${etcd}" ] && exit 1
etcd_size="$(echo $etcd | awk '{print $1}')"
# 524288000000 is 0.5 TiB; required for this disk.
# exit 0 ; this module does not need to run on this node unless it meets the requirements.
[ "${etcd_size}" -gt 524288000000 ] && exit 0

# DISKS
export etcd_disk="$(echo $etcd | awk '{print $2}')"
if [ "${metal_nowipe:-0}" = 0 ]; then
    [ ! -f /tmp/metaletcddisk.done ] && make_etcd "$etcd_disk"
fi
