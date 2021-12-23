#!/bin/bash
set -u
# metal-update-keystore
# This file copies our master-key to the overlayFS.
# The Operating System can expect to find the key at this same location.
# This script is dependent on 2 things:
#
#   1. rd.live.overlay=LABEL=ROOTRAID must be given and it must exist, otherwise this will exit. This
#
#   2. rd.luks.key=/pki/etcd.key:LABEL=ROOTRAID must be given so the OS knows to look for the key here.
#
# The values above can be anything, as long as their given and refer to the same device.
if [ $metal_noluks = 0 ]; then 
    echo >2 'skipping keystore management (no LUKS; rd.luks=0 was set on the cmdline)'
    exit 0
fi

# Define our keystore; this must be the same for any dracut-metal module.
keystore=/run/initramfs/overlayfs/pki

# Do not create parent directories with '-p'.etcd_master_key, if the parent
# does not exist then our persistent storage hasn't mounted or is invalid and
# we must fail.
mkdir -m 700 $keystore 2>/dev/null || chmod 700 $keystore

# Copy any new keys from our LUKS device(s).
# NOTE: In the future this may need to move into a common dracut lib if other dracut mods make keys.
[ -d $keystore ] && (
    cd "${metal_keystore:-/tmp/metalpki}" || warn the keystores not here man, this should never happen.
    for key in *.key; do
        [ -f "${keystore}/$key" ] || cp "${metal_keystore}/${key}" $keystore
    done
) || echo >&2 'Failed to add etcd master key to keystore - if this node reboots it may be irrecoverable and will likely need a clean-slate/disk-pave.'

# VIP: Only root should be able to check the keys out.
# Ensure any "new" sub-directories from tampering also conform.
find $keystore -type d -exec chmod 700 {} \+
find $keystore -type f -exec chmod 400 {} \+
