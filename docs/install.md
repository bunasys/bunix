# Installing bunix

Status: tested in QEMU (2026-11-03), on a disk laid out like a Windows PC,
and on real hardware next to Windows with Secure Boot on: install, updates
from GitHub (0.1.0 -> 0.1.1 -> 0.1.2), the devel, rust and swift
extensions.

## Two ways onto a disk

- **`bunix-install`**, on the live ISO (`files/install/bunix-install`): into
  free space, into an existing partition it deletes, or onto a whole disk.
  This is the way to dual-boot with Windows.
- **`bunix-x86_64.raw`** (`system/disk.bst`), written to a whole disk. Its
  root partition is created on first boot.

Both are UEFI only and give the same system, which updates itself the same
way (docs/updates.md).

## Dual-boot with Windows

1. In Windows, shrink C: in Disk Management to leave free space: at least
   about 12 GB, 30 GB or more to be comfortable. bunix-install does not
   resize file systems.
2. Boot the ISO and run `bunix-install`. It lists the disks, then the places
   on the chosen disk (free stretches, partitions, the whole disk) and marks
   the ones too small. Deleting a partition or erasing a disk has to be
   confirmed by typing its name.
3. To start bunix, pick "bunix" in the firmware's boot menu (F12, F11, Esc,
   ...). **Windows stays the default**: bunix-install puts its entry last in
   the firmware's boot order when a "Windows Boot Manager" entry exists, and
   first otherwise. systemd-boot's menu lists only bunix and stays hidden
   (hold Space while booting to see it): Windows starts from the firmware's
   boot menu, never through systemd-boot, so BitLocker sees no change in its
   boot chain.

Nothing outside the chosen place is written, except on the ESP, where
bunix-install adds `EFI/bunix/` (and `loader/loader.conf` if there is none).
`EFI/BOOT/BOOTX64.EFI` on a shared ESP is Windows' fallback loader and is
left alone. The test checks that the "Windows" partitions are unchanged,
byte for byte.

## The partitions

| Partition | Size | Why |
| --- | --- | --- |
| ESP | 512 MiB, only if the disk has none | firmware's boot partition |
| XBOOTLDR | 1 GiB | the kernel images (UKIs, ~31 MB each, two kept). A Windows ESP is 100 MB, too small; systemd-boot and sysupdate use XBOOTLDR when there is one |
| `/usr` slot A: data, verity, signature | 1 GiB, 16 MiB, 1 MiB | this release |
| `/usr` slot B: the same three | | empty, for the next update |
| root | the rest (at least 8 GiB) | ext4: /etc, /var, /home |

Nine partitions, ten with a new ESP. Most of them come from the A/B update
scheme: each `/usr` slot is three partitions (the erofs data, its dm-verity
hash tree, and the signed root hash), because that is how the UAPI
Discoverable Partitions Specification describes a verified `/usr`.

They are created with `sfdisk` at exact positions inside the chosen place,
so nothing lands in some other free stretch of the disk. The root partition
is created by the installer, not on first boot as with the disk image:
systemd-repart in the initrd would put it in whatever free space it found.

## Found on real hardware

- The firmware may not pass a boot entry's options to the program it
  starts. The "bunix" entry starts shim with options naming systemd-boot;
  without them shim starts `grubx64.efi` next to itself. So `EFI/bunix/`
  holds systemd-boot under that name too (system/esp.bst).
- efivarfs files report a size of 0; uutils `od -j` cannot skip into them,
  so the installer reads the Secure Boot variable through a pipe.

## Limits

- **Same disk as the ESP.** The initrd finds the root partition on the disk
  the boot loader came from. A disk without an ESP gets its own; installing
  to a second disk works, with its own ESP.
- **One bunix per disk.** The initrd and systemd-boot take the first root,
  XBOOTLDR and `/usr` partitions they find, so the installer refuses a disk
  that already has one, unless it is the partition being replaced or the
  whole disk is erased.
- **Secure Boot.** On the first boot shim stops in MokManager: choose
  "Enroll key from disk", then `EFI/bunix/bunix.cer`. (mokutil, which would
  queue the key from the installer, needs keyutils and libcrypt; not built
  yet.) Some newer PCs ship with Microsoft's third-party UEFI certificate
  turned off, and shim needs it; turn it on in the firmware's settings.
- **Clock.** Windows keeps the hardware clock in local time, bunix in UTC;
  `timedatectl set-local-rtc 1` in bunix makes them agree.

## Tests

```
truncate -s 24G out/dual/disk.raw
BOOT_DISK=out/dual/disk.raw BOOT_CHECKS=tools/boot-checks/install-windows.txt BOOT_MEMORY=2G \
  tools/boot-test.py bunix-x86_64.iso uefi out/dual
BOOT_CHECKS=tools/boot-checks/dual-boot.txt tools/boot-test.py any.raw uefi out/dual
```

The first run makes the "Windows" disk on the live ISO and installs into its
free space; the second boots it through the "bunix" entry and checks
`/boot` (XBOOTLDR), `/efi` (the shared ESP) and that systemd-boot lists
only bunix.
