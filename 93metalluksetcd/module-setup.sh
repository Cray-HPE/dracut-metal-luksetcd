#!/bin/bash
#
# MIT License
#
# (C) Copyright 2022-2024 Hewlett Packard Enterprise Development LP
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
# module-setup.sh

# called by dracut
check() {
    require_binaries basename blkid cryptsetup lvm lsblk mkfs.xfs mount parted partprobe || return 1
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

    # shellcheck disable=SC2154
    inst_simple "$moddir/metal-luksetcd-lib.sh" "/lib/metal-luksetcd-lib.sh"
    inst_script "$moddir/metal-luksetcd-disk.sh" /sbin/metal-luksetcd-disk

    inst_hook cmdline 10 "$moddir/parse-metal-luksetcd.sh"
    inst_hook pre-udev 10 "$moddir/metal-luksetcd-genrules.sh"

    # These copy our meta files into areas the pivoted rootfs can read from - they must run before
    # the root is chrooted.
    inst_hook pre-mount 11 "$moddir/metal-update-keystore.sh"
    
    # Unlock the device before mounting the rootfs
    inst_hook pre-mount 20 "$moddir/metal-luksetcd-unlock.sh"

    # We depend on information being gathered from the initqueue, if it fails or has nothing then
    # we should not run.
    dracut_need_initqueue
}
