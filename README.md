# Metal Linux Unified Key Setup Module for etcd (LUKS)

This module creates secure LUKS  partitions in the initramFS, during the boot of a node. Ultimately
this provides encrypted disks for use with etcd.

### Requires

See `module-setup.sh` for the full list, but this heavily depends on the `dracut-metal-mdsquash` module
(i.e. 98metalmdsquash).

### Key Generation

The encrypted disk needs a key to unlock, this key must be securely generated and preserved.

By default, the master-key is created when the disk is before being deposited in the storage array
for the root overlays.


Here is the overlayFS storage on a booted k8s-manager node. We see the `pki/` keystore.
```bash
ncn-m003:~ # ls -l /run/initramfs/overlayfs/
total 4
drwxr-xr-x 4 root root  82 Jan 11 09:02 LiveOS
-rw-r--r-- 1 root root 403 Jan 11 09:02 fstab.metal
drwx------ 2 root root  22 Jan 11 09:02 pki
```

Peering into the keystore we see our PLAIN-TEXT LUKS key.
```bash
ncn-m003:~ # ls -l /run/initramfs/overlayfs/pki/
total 4
-rw------- 1 root root 12 Jan 11 09:02 etcd.key
```

### Encryption Information 

The LUKS device uses a LUKS2 header, the new header format allowing additional
extensions such as newer Password-Based Key Derivation Function (PBKDF) algorithms.
 
The LUKS encryption uses argon2id PBKDF, a newer function.

(excerpt from [Wiki](https://en.wikipedia.org/wiki/Argon2))
Argon2d maximizes resistance to GPU cracking attacks. It accesses the memory array in a password dependent order, which reduces the possibility of time–memory trade-off (TMTO) attacks, but introduces possible side-channel attacks.
Argon2i is optimized to resist side-channel attacks. It accesses the memory array in a password independent order.
**Argon2id** is a hybrid version. It follows the Argon2i approach for the first half pass over memory and the Argon2d approach for subsequent passes. The Internet draft[4] recommends using Argon2id except when there are reasons to prefer one of the other two modes.


### Boot Options

```
# If named with .gpg suffix, a password prompt will appear.
rd.luks.key-file=/pki/etcd.key:LABEL=ROOTRAID

# Must be enabled
rd.luks=1

# Must be disabled to avoid surprises.
rd.luks.cryptab=0

# Must be disabled, or feel the wrath of surprise lvm.conf changes.
rd.lvm.conf=0

# Change the size; 10GB min, 64GB max.
metal.disk.etcdk8s.size=32
```


### Examples

Here's the layout on a booted k8s manager node.

1. Here is the disk partitions in `lsblk`:
    ```bash
    ncn:~ # lsblk
    NAME                MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINT
    loop0                 7:0    0   3.8G  1 loop  /run/rootfsbase
    loop1                 7:1    0    30G  0 loop
    └─live-overlay-pool 254:2    0   300G  0 dm
    loop2                 7:2    0   300G  0 loop
    └─live-overlay-pool 254:2    0   300G  0 dm
    sda                   8:0    0 447.1G  0 disk
    ├─sda1                8:1    0   476M  0 part
    │ └─md127             9:127  0   476M  0 raid1
    ├─sda2                8:2    0  92.7G  0 part
    │ └─md126             9:126  0  92.6G  0 raid1 /run/initramfs/live
    └─sda3                8:3    0 279.4G  0 part
      └─md125             9:125  0 279.3G  0 raid1 /run/initramfs/overlayfs
    sdb                   8:16   0 447.1G  0 disk
    ├─sdb1                8:17   0   476M  0 part
    │ └─md127             9:127  0   476M  0 raid1
    ├─sdb2                8:18   0  92.7G  0 part
    │ └─md126             9:126  0  92.6G  0 raid1 /run/initramfs/live
    └─sdb3                8:19   0 279.4G  0 part
      └─md125             9:125  0 279.3G  0 raid1 /run/initramfs/overlayfs
    sdc                   8:32   0 447.1G  0 disk
    └─ETCDLVM           254:0    0 447.1G  0 crypt
      └─etcdvg0-ETCDK8S 254:1    0    32G  0 lvm   /run/lib-etcd
    ```
2. Here's the overlay, showing our disk device being used as the upperdir (persistent) overlayFS.
    ```bash
    ncn:~ # mount | grep etcd_overlay
    etcd_overlayfs on /var/lib/etcd type overlay (rw,relatime,lowerdir=/var/lib/etcd,upperdir=/run/lib-etcd/overlayfs,workdir=/run/lib-etcd/ovlwork)
    ```
3. The `fstab.metal` file loaded by the `metalfs` systemd service
    ```bash
    ncn:~ # ls -l /run/initramfs/
    .need_shutdown  livedev         overlayfs/      thin-overlay/
    live/           log/            squashfs/       url-lib/
    ncn:~ # ls -l /run/initramfs/overlayfs/fstab.metal
    -rw-r--r-- 1 root root 292 Jan 12 14:23 /run/initramfs/overlayfs/fstab.metal
    ncn:~ # cat !$
    cat /run/initramfs/overlayfs/fstab.metal
    # metal-init
    LABEL=ETCDK8S     	/run/lib-etcd     	xfs	noatime,largeio,inode64,swalloc,allocsize=131072k,discard 0 2
    LABEL=ROOTIMG  /  ext4  defaults  0  1
    etcd_overlayfs    	/var/lib/etcd     	overlay	lowerdir=/var/lib/etcd,upperdir=/run/lib-etcd/overlayfs,workdir=/run/lib-etcd/ovlwork 0 2
    ```
