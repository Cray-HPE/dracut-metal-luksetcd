#!/bin/bash

# called by dracut
check() {
    require_binaries basename cryptsetup lvm mkfs.xfs parted || return 1
    return 
}

# called by dracut
depends() {
    echo metalmdsquash
    return 0
}

installkernel() {
    instmods hostonly='' dm-crypt
}

# called by dracut
install() {
    inst_multiple basename chmod cryptsetup lsblk lvcreate lvm mkfs.xfs parted pvs sort tail vgcreate

    inst_simple "$moddir/metal-luksetcd-lib.sh" "/lib/metal-luksetcd-lib.sh"
    inst_script "$moddir/metal-luksetcd-disk.sh" /sbin/metal-luksetcd-disk

    inst_hook cmdline 10 "$moddir/parse-metal-luksetcd.sh"
    inst_hook pre-udev 10 "$moddir/metal-luksetcd-genrules.sh"

    # These copy our meta files into areas the pivoted rootfs can read from - they must run before
    # the root is chrooted.
    inst_hook pre-mount 11 "$moddir/metal-update-keystore.sh"

    # Unlock etcd; kernel params may not be enough without disabling systemd.
    inst_hook pre-mount 12 "$moddir/metal-luksetcd-unlock.sh"

    # We depend on information being gathered from the initqueue, if it fails or has nothing then
    # we should not run.
    dracut_need_initqueue
}
