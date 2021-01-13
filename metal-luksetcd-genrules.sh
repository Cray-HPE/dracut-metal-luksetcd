#!/bin/sh

[ -z "${metal_debug:-0}" ] || set -x

# Only run when we're being provisioned by a metal.server
if [ -n "${metal_server:-}" ]; then
    /sbin/initqueue --settled --onetime --unique /sbin/metal-luksetcd-disk
fi