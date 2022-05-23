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
# parse-metal-luksetcd.sh
command -v getarg > /dev/null 2>&1 || . /lib/dracut-lib.sh
command -v _overlayFS_path_spec > /dev/null 2>&1 || . /lib/metal-lib.sh

getargbool 0 metal.debug -d -y metal_debug && metal_debug=1
[ "${metal_debug:-0}" = 0 ] || set -x

# Affixed size:
metal_size_etcdk8s=$(getargnum 32 10 64 metal.disk.etcdk8s.size)

getargbool 0 metal.no-wipe -d -y metal_nowipe && metal_nowipe=1 || metal_nowipe=0
getargbool 0 rd.luks -d -n rd_NO_LUKS && metal_noluks=1 || metal_noluks=0

metal_etcdlvm=$(getarg metal.disk.etcdlvm)
[ -z "${metal_etcdlvm}" ] && metal_etcdlvm=LABEL=ETCDLVM
metal_etcdk8s=$(getarg metal.disk.etcdk8s)
[ -z "${metal_etcdk8s}" ] && metal_etcdk8s=LABEL=ETCDK8S

export metal_etcdk8s
export metal_etcdlvm
export metal_noluks 
export metal_debug
export metal_size_etcdk8s
export metal_nowipe

# keystores - this ought to be universal for all metal dracut modules needing private keys.
export metal_keystore="/run/initramfs/overlayfs/pki"
# metal_tmp_keystore MUST EXIST ON AN EPHEMERAL FILESYSTEM ; /tmp/ is cleared when the system pivots to squashFS thus it's sufficient.
export metal_tmp_keystore=/tmp/metalpki
