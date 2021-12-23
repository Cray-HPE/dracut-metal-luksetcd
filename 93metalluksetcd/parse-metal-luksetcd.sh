#!/bin/bash
#
# Copyright 2020 Hewlett Packard Enterprise Development LP
#
# metal.disk.etcdk8s.size: Changes the size (in Gigabytes) for the etcd volume.
# > metal.disk.etcdk8s.size=32
#
type getarg > /dev/null 2>&1 || . /lib/dracut-lib.sh

getargbool 0 metal.debug -d -y metal_debug && metal_debug=1
# Affixed size:
metal_size_etcdk8s=$(getargnum 32 10 64 metal.disk.etcdk8s.size)

getargbool 0 metal.no-wipe -d -y metal_nowipe && metal_nowipe=1 || metal_nowipe=0
getargbool 0 rd.luks -d -n rd_NO_LUKS && metal_noluks=1 || metal_noluks=0

export metal_noluks 
export metal_debug
export metal_size_etcdk8s
export metal_nowipe

# keystore - this ought to be universal for all metal dracut modules needing private keys.
# THIS MUST EXIST ON AN EPHEMERAL SYSTEM ; /tmp/ is cleared when the system pivots to squashFS thus it's sufficient.
export metal_keystore=/tmp/metalpki
