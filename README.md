# METAL 93luksetcd - management of LUKS & LVM for etcd and more

This module manages LUKS devices by encyrpting an entire disk with a securely generated key. The key is deposited in a dependent overlayFS for re-use.

The encrypted disk is provided with LVM, and an initial volume group dedicated to etcd.

# Parameters

The following parameters can customize the behavior of 93luksetcd.

## Customizable Parameters

### FSLabel Parameters

The FS labels can be changed from their default values.
This may be desirable for cases when another LVM is being re-used.

##### `metal.disk.etcdlvm=ETCDLVM`

> FSLabel for the LVM device, this is the same device as the LUKS device. This is what the key unlocks.

##### `metal.disk.etcdk8s=ETCDK8S`

> FSLabel for the etcd volume.

### Partition or Volume Size(s) Parameters

##### `metal.disk.etcdk8s.size=32`

> Size of the /run/lib-etcd overlayFS in Gigabytes (`GB`):
>
> * default: 32
> * min: 10
> * max: 64

## Required Parameters

The following parameters are required for this module to work, however they belong to the native dracut space.

> See [`module-setup.sh`](./93metalluksetcd/module-setup.sh) for the full list of module and driver dependencies.

##### `rd.luks=1`

> Enable or disable both LUKS _and_ this module. If this parameter is omitted or set to `0` then 93luksetcd will stand-down.

##### `rd.luks.cryptab=0`

> Ignore any built-in crypttab and always scan for LUKS devices. **Warning**, this should be left alone.

##### `rd.lvm.conf=0`

> Ignore any built-in `/etc/lvm.conf` files; prevent overrides.

## LUKS Key Generation

The encrypted disk needs a key to unlock, this key must be securely generated and preserved.

By default, the master-key is created when the disk is before being deposited in the storage array
for the root overlays.

Here is the overlayFS storage on a booted k8s-manager node. We see the `pki/` keystore.
```bash
ncn-m001:~ # cat /etc/fstab.metal
LABEL=ETCDK8S     	/run/lib-etcd     	xfs	noatime,largeio,inode64,swalloc,allocsize=131072k 0 2
etcd_overlayfs    	/var/lib/etcd     	overlay	lowerdir=/var/lib/etcd,upperdir=/run/lib-etcd/overlayfs,workdir=/run/lib-etcd/ovlwork 0 2
#
LABEL=BOOTRAID	/metal/boot	vfat	defaults	0	0
```

Peering into the keystore we see our PLAIN-TEXT LUKS key.
```bash
ncn-m001:~ # ls -l /run/initramfs/overlayfs/pki/
total 4
-r-------- 1 root root 12 Mar  9 23:29 etcd.key
```

### Encryption Background

#### Key Source

The `12`-character keys are generated for each LUKS device by following snippet:

[metal-luksetcd-lib.sh](./93metalluksetcd/metal-luksetcd-lib.sh#23-27)
```bash
tr < /dev/urandom -dc _A-Z-a-z-0-9 | head -c 12 > "$etcd_keystore"
```

This generation is primitive, however it is isolated. The key is generated during first-boot and never passed into console or over the network.

#### LUKS Device

The LUKS device uses a LUKS2 header, the new header format allowing additional
extensions such as newer Password-Based Key Derivation Function (PBKDF) algorithms.

The LUKS encryption uses argon2id PBKDF, a newer function.

> (excerpt from [Wiki](https://en.wikipedia.org/wiki/Argon2))
> Argon2d maximizes resistance to GPU cracking attacks. It accesses the memory array in a password dependent order, which reduces the possibility > of time–memory trade-off (TMTO) attacks, but introduces possible side-channel attacks.
> Argon2i is optimized to resist side-channel attacks. It accesses the memory array in a password independent order.
**Argon2id** is a hybrid version. It follows the Argon2i approach for the first half pass over memory and the Argon2d approach for subsequent passes. The Internet draft[4] recommends using Argon2id except when there are reasons to prefer one of the other two modes.

## Runtime Examples

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
