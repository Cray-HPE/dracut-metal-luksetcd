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
# parse-metal-luksetcd.sh
command -v getarg > /dev/null 2>&1 || . /lib/dracut-lib.sh
command -v _overlayFS_path_spec > /dev/null 2>&1 || . /lib/metal-lib.sh

getargbool 0 metal.debug -d -y METAL_DEBUG && METAL_DEBUG=1
[ "${METAL_DEBUG:-0}" = 0 ] || set -x

# Affixed size:
METAL_SIZE_ETCDK8S=$(getargnum 32 10 64 metal.disk.etcdk8s.size)

getargbool 0 metal.no-wipe -d -y METAL_NOWIPE && METAL_NOWIPE=1 || METAL_NOWIPE=0
getargbool 0 rd.luks -d -n rd_NO_LUKS && METAL_NOLUKS=1 || METAL_NOLUKS=0

METAL_ETCDLVM=$(getarg metal.disk.etcdlvm)
[ -z "${METAL_ETCDLVM}" ] && METAL_ETCDLVM=LABEL=ETCDLVM
METAL_ETCDK8S=$(getarg metal.disk.etcdk8s)
[ -z "${METAL_ETCDK8S}" ] && METAL_ETCDK8S=LABEL=ETCDK8S
export METAL_ETCDK8S
export METAL_ETCDLVM
export METAL_NOLUKS
export METAL_DEBUG
export METAL_SIZE_ETCDK8S
export METAL_NOWIPE

# keystores - this ought to be universal for all metal dracut modules needing private keys.
export METAL_KEYSTORE="/run/initramfs/overlayfs/pki"
# METAL_TMP_KEYSTORE MUST EXIST ON AN EPHEMERAL FILESYSTEM ; /tmp/ is cleared when the system pivots to squashFS thus it's sufficient.
export METAL_TMP_KEYSTORE=/tmp/metalpki
