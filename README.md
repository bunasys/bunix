# bunix (Buna Linux)

A Linux system built from source, with its own toolchain bootstrap, laid out
by the UAPI Linux File System Hierarchy, and updated as whole images.

This repository hosts bunix's **releases**: each one holds

| File | What it is |
| --- | --- |
| `bunix-x86_64.iso` | the live system and installer (UEFI, Secure Boot) |
| `bunix_<version>.usr-x86-64*.raw` | the system's `/usr`: erofs, dm-verity hash tree, signed root hash |
| `bunix_<version>.efi` | the signed kernel image (UKI) that boots it |
| `devel_<version>.raw` | the development toolchain, a system extension (gcc, make, cmake, meson, headers) |
| `SHA256SUMS`, `SHA256SUMS.gpg` | the manifest and its OpenPGP signature, by the bunix release key |

Installed systems update themselves from here with `systemd-sysupdate`, A/B,
with automatic rollback; every file is checked against the signed manifest
and, for images, their dm-verity signatures.

## Toolchain on a running system

```
mkdir -p /etc/sysupdate.d/devel.feature.d
printf '[Feature]\nEnabled=true\n' > /etc/sysupdate.d/devel.feature.d/enable.conf
/usr/lib/systemd/systemd-sysupdate update
systemd-sysext refresh
```

## Updating the system

```
/usr/lib/systemd/systemd-sysupdate update
reboot
```
