#!/bin/sh
#
# Copyright 2020 Hewlett Packard Enterprise Development LP
#
# metal.disk.etcdk8s.size: Changes the size (in Gigabytes) for the etcd volume.
# > metal.disk.etcdk8s.size=32
#
# metal.disk.etcdk8s.size: Changes the size (in Gigabytes) for the etcd volume.
# > metal.disk.etcdvault.size=32
#
type getarg > /dev/null 2>&1 || . /lib/dracut-lib.sh

getargbool 0 metal.debug -d -y metal_debug && metal_debug=1
# Affixed size:
metal_size_etcdk8s=$(getargnum 32 10 64 metal.disk.etcdk8s.size)
metal_size_etcdvault=$(getargnum 32 10 64 metal.disk.etcdvault.size)

getargbool 0 metal.no-wipe -d -y metal_nowipe && metal_nowipe=1 || metal_nowipe=0

export metal_debug
export metal_size_
export metal_size_etcdk8s
export metal_size_etcdvault
export metal_nowipe

# keystore - this ought to be universal for all metal dracut modules needing private keys.
# THIS MUST EXIST ON AN EPHEMERAL SYSTEM ; /tmp/ is cleared when the system pivots to squashFS thus it's sufficient.
export metal_keystore=/tmp/metalpki