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
# metal-luksetcd-lib.sh
[ "${metal_debug:-0}" = 0 ] || set -x

command -v info >/dev/null 2>&1 || . /lib/dracut-lib.sh
command -v metal_die >/dev/null 2>&1 || . /lib/metal-lib.sh

make_etcd() {
    
    # Check if the disk exists and cancel if it does.
    local etcdk8s_scheme=${metal_etcdk8s%=*}
    local etcdk8s_authority=${metal_etcdk8s#*=}
    if blkid -s UUID -o value "/dev/disk/by-${etcdk8s_scheme,,}/${etcdk8s_authority^^}"; then
        # echo 0 to signal that this module didn't need to create a disk, it existed already.
        echo 0 > /tmp/metaletcddisk.done && return
    fi
    
    local target="${1:-}" && shift
    [ -z "$target" ] && info 'No etcd disk.' && return 0

    local etcd_key_file=etcd.key
    local etcd_keystore="${metal_tmp_keystore}/${etcd_key_file}"

    # Generate our key.
    (
        mkdir -p "${metal_tmp_keystore}"
        tr < /dev/urandom -dc _A-Z-a-z-0-9 | head -c 12 > "$etcd_keystore"
        chmod 600 "$etcd_keystore"
    )
    [ -f "${etcd_keystore}" ] || metal_die 'FATAL could not generate master-key; temp-keystore failed to create or is invalid'

    # Wipe our disk.
    parted --wipesignatures --ignore-busy -s "/dev/${target}" mktable gpt

    # NVME partitions have a "p" to delimit the partition number.
    if [[ "$target" =~ "nvme" ]]; then
        target="${target}p" 
    fi

    # LUKS2 header requires multiple writes, silence warnings of race-condition when /run/cryptsetup does not exist
    # citation: https://lists.debian.org/debian-boot/2019/02/msg00100.html
    info Attempting luksFormat of "/dev/${target}" ...
    mkdir -p -m 0700 /run/cryptsetup
    cryptsetup --key-file "${etcd_keystore}" \
            --batch-mode \
            --verbose \
            --type=luks2 \
            --pbkdf=argon2id \
            --label="${metal_etcdlvm#*=}" \
            --subsystem="${metal_etcdlvm#*=}" \
            luksFormat "/dev/${target}" || warn Could not format LUKS device ... ignoring ...
    info Attempting luksOpen of "${ETCDLVM:-ETCDLVM}" ...
    cryptsetup --key-file "${etcd_keystore}" \
            --verbose \
            --batch-mode \
            --allow-discards \
            --type=luks2 \
            --pbkdf=argon2id \
            luksOpen "/dev/${target}" "${ETCDLVM:-ETCDLVM}" || warn FATAL could not open LUKS device for ETCD

    # Start with etcdvg0 to allow for etcdvgN for new etcd volume groups.
    lvm pvcreate -M lvm2 "/dev/mapper/${ETCDLVM:-ETCDLVM}"
    vgcreate etcdvg0 "/dev/mapper/${ETCDLVM:-ETCDLVM}"
    lvcreate -L "${metal_size_etcdk8s:-32}G" -n ${metal_etcdk8s#*=} etcdvg0

    mkfs.xfs -L ${metal_etcdk8s#*=} /dev/mapper/etcdvg0-${metal_etcdk8s#*=} || warn Failed to create "${metal_etcdk8s#*=}"

    mkdir -m 700 -pv /var/lib/etcd /run/lib-etcd
    printf '% -18s\t% -18s\t%s\t%s 0 2\n' "${metal_etcdk8s}" /run/lib-etcd xfs "$metal_fsopts_xfs" >>$metal_fstab

    # Mount our new partitions, and create any and all overlayFS prereqs.
    mount -a -v -T $metal_fstab && mkdir -m 700 -p /run/lib-etcd/ovlwork /run/lib-etcd/overlayfs

    # Add our etcd overlay to the metal fstab and issue another mount.
    printf '% -18s\t% -18s\t%s\t%s 0 2\n' etcd_overlayfs /var/lib/etcd overlay lowerdir=/var/lib/etcd,upperdir=/run/lib-etcd/overlayfs,workdir=/run/lib-etcd/ovlwork >> $metal_fstab

    # Mount FS again, catching our new overlayFS. Failure to mount here is fatal.
    mount -a -v -T $metal_fstab

    echo 1 > /tmp/metaletcddisk.done && return
}

# this step-child function exists because we can't get kernel parameters right.
unlock() {
    local target="${1:-}" && shift
    [ -z "$target" ] && info 'No etcd disk.' && return 0

    local etcd_key_file='etcd.key'
    local etcd_keystore="$metal_keystore/${etcd_key_file}"
    cryptsetup --key-file "${etcd_keystore}" \
            --verbose \
            --batch-mode \
            --allow-discards \
            --type=luks2 \
            --pbkdf=argon2id \
            luksOpen "/dev/${target}" "${ETCDLVM:-ETCDLVM}" || warn FATAL could not open LUKS device for ETCD
}
