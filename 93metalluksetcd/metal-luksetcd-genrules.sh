#!/bin/bash

command -v getarg >/dev/null || . /lib/dracut-lib.sh

[ -z "${metal_debug:-0}" ] || set -x

# Only run when we're being provisioned by a metal.server
if getargbool 0 rd.luks -d -n rd_NO_LUKS; then
    /sbin/initqueue --settled --onetime --unique /sbin/metal-luksetcd-disk
fi
