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
# metal-update-keystore.sh

# This file copies our master-key to the overlayFS.
# The values above can be anything, as long as their given and refer to the same device.
# The Operating System can expect to find the key at this same location.
# This script is dependent on 2 things:
#
#   1. rd.live.overlay=LABEL=ROOTRAID must be given and it must exist, otherwise this will exit.
#
#   2. rd.luks=1 (or rd.luks) must be set to enable this function.
#
[ "${metal_debug:-0}" = 0 ] || set -x

if [ $metal_noluks = 0 ]; then 
    echo >&2 'skipping keystore management (no LUKS; rd.luks=0 was set on the cmdline)'
    exit 0
fi

# Ensure any "new" sub-directories from tampering also conform.
perms() {
    # VIP: Only root should be able to check the keys out.
    find $metal_keystore -type d -exec chmod 700 {} \+
    find $metal_keystore -type f -exec chmod 400 {} \+
}

command -v getarg > /dev/null 2>&1 || . /lib/dracut-lib.sh

case "$(getarg root)" in 
    kdump)
        # do not do anything for kdump
        exit 0
        ;;
    *)
        trap perms EXIT
        ;;
esac

# Do not create parent directories with '-p'.etcd_master_key, if the parent
# does not exist then our persistent storage hasn't mounted or is invalid and
# we must fail.
mkdir -m 700 $metal_keystore 2>/dev/null || chmod 700 $metal_keystore

# Copy any new keys from our LUKS device(s).
# NOTE: In the future this may need to move into a common dracut lib if other dracut mods make keys.
[ -d $metal_tmp_keystore ] && (
    keys=$(find /tmp -name *.key)
    for key in $keys; do
        cp -pv "$key" "$metal_keystore/" || echo >&2 'Failed to add etcd master key to keystore - if this node reboots it may be irrecoverable and will likely need a clean-slate/disk-pave.'
    done
)
