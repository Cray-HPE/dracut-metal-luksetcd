#!/bin/bash

type info >/dev/null 2>&1 || . /lib/dracut-lib.sh

# Can remove this once metal-lib.sh is merged into production.
if [ -f /lib/metal-lib.sh ]; then
    type metal_die >/dev/null 2>&1 || . /lib/metal-lib.sh
else
    # legacy; load it from this lib file.
    type metal_die >/dev/null 2>&1 || . /lib/metal-md-lib.sh
fi

metal_etcdlvm=$(getarg metal.disk.etcdlvm)
[ -z "${metal_etcdlvm}" ] && metal_etcdlvm=LABEL=ETCDLVM
metal_etcdk8s=$(getarg metal.disk.etcdk8s)
[ -z "${metal_etcdk8s}" ] && metal_etcdk8s=LABEL=ETCDK8S

make_etcd() {
    local target="${1:-}" && shift
    [ -z "$target" ] && info 'No etcd disk.' && return 0

    local etcd_key_file=etcd.key
    local etcd_keystore="${metal_keystore:-/tmp/metalpki}/${etcd_key_file}"

    # Generate our key.
    (
        mkdir -p "${metal_keystore:-/tmp/metalpki}"
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
    local etcd_keystore="/run/initramfs/overlayfs/pki/${etcd_key_file}"
    cryptsetup --key-file "${etcd_keystore}" \
            --verbose \
            --batch-mode \
            --allow-discards \
            --type=luks2 \
            --pbkdf=argon2id \
            luksOpen "/dev/${target}" "${ETCDLVM:-ETCDLVM}" || warn FATAL could not open LUKS device for ETCD
}
