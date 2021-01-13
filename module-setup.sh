#!/bin/bash

# called by dracut
check() {
    return 0
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
    inst_multiple parted mkfs.xfs lsblk sort tail lvm vgcreate lvcreate cryptsetup pvs

    inst_simple "$moddir/metal-luksetcd-lib.sh" "/lib/metal-luksetcd-lib.sh"
    inst_script "$moddir/metal-luksetcd-disk.sh" /sbin/metal-luksetcd-disk

    inst_hook cmdline 10 "$moddir/parse-metal-luksetcd.sh"
    inst_hook pre-udev 10 "$moddir/metal-luksetcd-genrules.sh"

    # These copy our meta files into areas the pivoted rootfs can read from - they must run before
    # the root is chrooted.
    inst_hook pre-pivot 10 "$moddir/metal-update-fstab.sh"
    inst_hook pre-pivot 10 "$moddir/metal-update-keystore.sh"

    # We depend on information being gathered from the initqueue, if it fails or has nothing then
    # we should not run.
    dracut_need_initqueue
}
