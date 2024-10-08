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
# metal-luksetcd-unlock.sh
[ "${METAL_DEBUG:-0}" = 0 ] || set -x

command -v metal_die > /dev/null 2>&1 || . /lib/metal-lib.sh

exec > "${METAL_LOG_DIR}/metal-luksetcd-unlock.log" 2>&1

command -v getarg > /dev/null 2>&1 || . /lib/dracut-lib.sh

case "$(getarg root)" in
  kdump)
    # do not do anything for kdump
    exit 0
    ;;
esac

if [ $METAL_NOLUKS = 0 ]; then
  echo >&2 'skipping unlocking of LUKS devices (rd.luks=0 was set on the cmdline)'
  exit 0
fi

etcdk8s_scheme=${METAL_ETCDK8S%=*}
etcdk8s_authority=${METAL_ETCDK8S#*=}

# Only run on reboots, when we don't create this file from the creation method.
if ! blkid -s UUID -o value "/dev/disk/by-${etcdk8s_scheme,,}/${etcdk8s_authority^^}" > /dev/null; then
  etcd_disk=$(blkid -L "${METAL_ETCDLVM##*=}")
  etcd_key_file='etcd.key'
  etcd_keystore="$METAL_KEYSTORE/${etcd_key_file}"
  if [ ! -f "$etcd_keystore" ]; then
    echo >&2 "Missing etcd key at $etcd_keystore"
    exit 1
  fi
  cryptsetup --key-file "${etcd_keystore}" \
    --verbose \
    --batch-mode \
    --allow-discards \
    --type=luks2 \
    luksOpen "${etcd_disk}" "${ETCDLVM:-ETCDLVM}"
  /sbin/lvm_scan
fi
