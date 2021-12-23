#!/bin/bash
# metal-luksetcd-unlock.sh
if [ $metal_noluks = 0 ]; then 
    echo >2 'skipping unlocking of LUKS devices (rd.luks=0 was set on the cmdline)'
    exit 0
fi

type unlock > /dev/null 2>&1 || . /lib/metal-luksetcd-lib.sh

# Only run on reboots, when we don't create this file from the creation method.
[ ! -f /tmp/metaletcddisk.done ] && unlock "$(basename $(blkid -L ${metal_etcdlvm##*=}))"
