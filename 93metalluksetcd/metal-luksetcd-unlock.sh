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
# metal-luksetcd-unlock.sh
[ "${metal_debug:-0}" = 0 ] || set -x

if [ $metal_noluks = 0 ]; then 
    echo >2 'skipping unlocking of LUKS devices (rd.luks=0 was set on the cmdline)'
    exit 0
fi

command -v unlock > /dev/null 2>&1 || . /lib/metal-luksetcd-lib.sh

# Only run on reboots, when we don't create this file from the creation method.
device="$(blkid -L ${metal_etcdlvm##*=})"
device_name="$(basename $device)"
[ ! -f /tmp/metaletcddisk.done ] && unlock $device_name 
