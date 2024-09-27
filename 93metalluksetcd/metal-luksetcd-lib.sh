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
# metal-luksetcd-lib.sh
[ "${METAL_DEBUG:-0}" = 0 ] || set -x

command -v info >/dev/null 2>&1 || . /lib/dracut-lib.sh

export ETCD_DONE_FILE=/tmp/metaletcddisk.done

##############################################################################
# function: scan_etcd
#
# Prints the etcd disk if it already exists, otherwise returns nothing.
#
scan_etcd() {

    local etcd_disk
    local etcdlvm_scheme=${metal_etcdlvm%=*}
    local etcdlvm_authority=${metal_etcdlvm#*=}
    local etcdlvm_scheme=${METAL_ETCDLVM%=*}
    local etcdlvm_authority=${METAL_ETCDLVM#*=}

    if blkid -s UUID -o value "/dev/disk/by-${etcdlvm_scheme,,}/${etcdlvm_authority^^}" >/dev/null; then
        etcd_disk="$(blkid -L "${METAL_ETCDLVM##*=}")"
        echo -n "$etcd_disk"
    fi
}

##############################################################################
# function: make_etcd
#
# Returns 0 if a disk was partitioned and encrypted, otherwise this calls
# metal_die with a contextual error message.
#
# Requires 1 argument for which disk:
#
#   sda
#   nvme0
#
# NOTE: The disk name must be given without any partitions or `/dev` prefixed
#       paths.
make_etcd() {

    local target="${1:-}" && shift
    if [ -z "$target" ]; then
        info 'No etcd disk.'
        echo 0 > $ETCD_DONE_FILE
        return 0
    fi

    local etcd_key_file=etcd.key
    local etcd_keystore="${METAL_TMP_KEYSTORE}/${etcd_key_file}"

    # Generate our key.
    (
        mkdir -p "${METAL_TMP_KEYSTORE}"
        tr < /dev/urandom -dc _A-Z-a-z-0-9 | head -c 12 > "$etcd_keystore"
        chmod 600 "$etcd_keystore"
    )
    [ -f "${etcd_keystore}" ] || metal_luksetcd_die 'FATAL could not generate master-key; temp-keystore failed to create or is invalid'

    # Wipe our disk.
    parted --wipesignatures --ignore-busy -s "/dev/${target}" mktable gpt

    # LUKS2 header requires multiple writes, silence warnings of race-condition when /run/cryptsetup does not exist
    # citation: https://lists.debian.org/debian-boot/2019/02/msg00100.html
    info Attempting luksFormat of "/dev/${target}" ...
    mkdir -p -m 0700 /run/cryptsetup
    cryptsetup --key-file "${etcd_keystore}" \
            --batch-mode \
            --verbose \
            --type=luks2 \
            --pbkdf=argon2id \
            --label="${METAL_ETCDLVM#*=}" \
            --subsystem="${METAL_ETCDLVM#*=}" \
            luksFormat "/dev/${target}" || metal_luksetcd_die 'Could not format LUKS device!'
    info Attempting luksOpen of "${ETCDLVM:-ETCDLVM}" ...
    cryptsetup --key-file "${etcd_keystore}" \
            --verbose \
            --batch-mode \
            --allow-discards \
            --type=luks2 \
            luksOpen "/dev/${target}" "${ETCDLVM:-ETCDLVM}" || metal_luksetcd_die 'FATAL could not open LUKS device for ETCD'

    # Start with etcdvg0 to allow for etcdvgN for new etcd volume groups.
    lvm pvcreate -M lvm2 "/dev/mapper/${ETCDLVM:-ETCDLVM}"
    vgcreate etcdvg0 "/dev/mapper/${ETCDLVM:-ETCDLVM}"
    lvcreate -L "${METAL_SIZE_ETCDK8S:-32}G" -n ${METAL_ETCDK8S#*=} etcdvg0

    mkfs.xfs -L "${METAL_ETCDK8S#*=}" "/dev/mapper/etcdvg0-${METAL_ETCDK8S#*=}" || metal_luksetcd_die "Failed to create ${METAL_ETCDK8S#*=}"

    mkdir -m 700 -pv /var/lib/etcd /run/lib-etcd
    printf '% -18s\t% -18s\t%s\t%s 0 2\n' "${METAL_ETCDK8S}" /run/lib-etcd xfs "$METAL_FSOPTS_XFS" >> "$METAL_FSTAB"

    # Mount our new partitions, and create any and all overlayFS prereqs.
    mount -a -v -T $metal_fstab && mkdir -m 700 -p /run/lib-etcd/ovlwork /run/lib-etcd/overlayfs

    # Add our etcd overlay to the metal fstab and issue another mount.
    printf '% -18s\t% -18s\t%s\t%s 0 2\n' etcd_overlayfs /var/lib/etcd overlay lowerdir=/var/lib/etcd,upperdir=/run/lib-etcd/overlayfs,workdir=/run/lib-etcd/ovlwork >> "$METAL_FSTAB"

    # Mount FS again, catching our new overlayFS. Failure to mount here is fatal.
    mount -a -v -T "$METAL_FSTAB"

    echo 1 > $ETCD_DONE_FILE && return
}

##############################################################################
# function: metal_luksetcd_die
#
# Calls metal_die, printing this module's URL to its source code first.
#
metal_luksetcd_die() {
    command -v metal_die > /dev/null 2>&1 || . /lib/metal-lib.sh
    echo >&2 "GitHub/Docs: https://github.com/Cray-HPE/dracut-metal-luksetcd"
    metal_die $*
}
