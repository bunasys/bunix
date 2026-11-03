kind: manual
description: |
  bunix-x86_64.raw: an installable disk image (docs/updates.md, step 2),
  to be written to a whole disk.  GPT, laid out by the UAPI Discoverable
  Partitions Specification:

    ESP          shim -> systemd-boot -> bunix_<release>.efi (system/uki.bst);
                 on first boot shim's fallback creates the "bunix" boot entry
    /usr slot A  this release (system/usr.bst): data, verity, signature
    /usr slot B  empty ("_empty"), for the next update
    root         none yet: systemd-repart creates it on first boot in the
                 space after the image, and grows it to the end of the disk

  UEFI only.  Boot chain under Secure Boot: firmware -> shim (Microsoft) ->
  systemd-boot and the UKI (bunix Secure Boot key, enrolled with
  MokManager) -> /usr (dm-verity, root hash in the signed UKI).

(@): include/release.yml

build-depends:
- bootstrap/build-env.bst
# systemd-repart; mkfs.vfat and mtools for the ESP
- base/systemd.bst
- base/dosfstools.bst
- base/mtools.bst
- system/esp.bst
- filename: system/usr.bst
  config:
    location: /usr-partitions
- filename: system/uki.bst
  config:
    location: /uki

variables:
  # A /usr slot's size: room for /usr to grow over future releases
  usr-slot-size: 1G
  # dm-verity's hash tree is 1/128 of the data it covers (32-byte SHA-256
  # hashes of 4 KiB blocks): 8 MiB for a full slot, so 16 MiB is twice that
  usr-verity-size: 16M
  usr-signature-size: 1M

config:
  build-commands:
  - |
    # The ESP: the boot files (system/esp.bst) and the UKI.  The firmware
    # has no boot entry for a newly written disk, so it starts
    # EFI/BOOT/BOOTX64.EFI -- shim, which runs fallback; fallback creates the
    # "bunix" entry from EFI/bunix/BOOTX64.CSV and reboots into it.
    mkdir -p tmp tree
    cp -a /usr/lib/bunix/esp tree/esp
    mkdir -p tree/esp/EFI/Linux
    cp /uki/bunix_%{release-version}.efi tree/esp/EFI/Linux/
    find tree/esp -type f | sort

  - |
    # The disk's partitions.  Slot A gets this release's partition images
    # with the UUIDs in their file names (they are derived from the root
    # hash the UKI names); slot B is left empty, labelled "_empty", which is
    # where sysupdate writes the next release.
    mkdir -p disk.d
    usr=$(ls /usr-partitions/*.usr-x86-64.*.raw)
    verity=$(ls /usr-partitions/*.usr-x86-64-verity.*.raw)
    signature=$(ls /usr-partitions/*.usr-x86-64-verity-sig.*.raw)
    uuid_of() { basename "$1" .raw | sed 's/.*\.//'; }
    partition() {
      file=$1; shift
      printf '%s\n' '[Partition]' "$@" > disk.d/$file
    }
    partition 00-esp.conf Type=esp Format=vfat CopyFiles=/esp:/ \
      SizeMinBytes=256M SizeMaxBytes=256M
    partition 10-usr-a.conf Type=usr Label=bunix_%{release-version} \
      UUID=$(uuid_of $usr) CopyBlocks=$usr ReadOnly=yes \
      SizeMinBytes=%{usr-slot-size} SizeMaxBytes=%{usr-slot-size}
    partition 11-usr-a-verity.conf Type=usr-verity Label=bunix_%{release-version}_verity \
      UUID=$(uuid_of $verity) CopyBlocks=$verity ReadOnly=yes \
      SizeMinBytes=%{usr-verity-size} SizeMaxBytes=%{usr-verity-size}
    partition 12-usr-a-verity-sig.conf Type=usr-verity-sig \
      Label=bunix_%{release-version}_verity_sig \
      UUID=$(uuid_of $signature) CopyBlocks=$signature ReadOnly=yes \
      SizeMinBytes=%{usr-signature-size} SizeMaxBytes=%{usr-signature-size}
    partition 20-usr-b.conf Type=usr Label=_empty \
      SizeMinBytes=%{usr-slot-size} SizeMaxBytes=%{usr-slot-size}
    partition 21-usr-b-verity.conf Type=usr-verity Label=_empty \
      SizeMinBytes=%{usr-verity-size} SizeMaxBytes=%{usr-verity-size}
    partition 22-usr-b-verity-sig.conf Type=usr-verity-sig Label=_empty \
      SizeMinBytes=%{usr-signature-size} SizeMaxBytes=%{usr-signature-size}
    head -50 disk.d/*

  - |
    # as system/usr.bst: offline, a writable TMPDIR, fixed seed
    export TMPDIR=$PWD/tmp
    /usr/bin/systemd-repart --empty=create --size=auto --dry-run=no --offline=yes \
      --definitions=disk.d --copy-source=$PWD/tree \
      --seed=c1d3f7a9-3e5b-4c8d-a2f6-7b9e0d1c4a58 \
      bunix-x86_64.raw
    ls -l bunix-x86_64.raw

  install-commands:
  - install -D -m 0644 bunix-x86_64.raw %{install-root}/bunix-x86_64.raw
