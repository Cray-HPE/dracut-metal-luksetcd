#!/bin/sh
# metal-luksetcd-unlock.sh

type unlock > /dev/null 2>&1 || . /lib/metal-luksetcd-lib.sh

# Only run on reboots, when we don't create this file from the creation method.
[ ! -f /tmp/metaletcddisk.done ] && unlock "$(basename $(blkid -L ${metal_etcdlvm##*=}))"
