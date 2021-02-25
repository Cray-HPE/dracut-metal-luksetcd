#!/bin/sh
# metal-update-crypttab

crypttab_new=/etc/crypttab
crypttab_old=/sysroot/etc/crypttab

cp -pv ${crypttab_old}.merge ${crypttab_old}
