kind: manual
description: |
  bunix-x86_64.iso: the live system, for UEFI machines -- with Secure Boot
  on -- from a CD or written raw to a USB stick.  The whole root file system
  is the initramfs, so once the kernel image is loaded nothing needs to find
  the boot medium again (bunix-install mounts it, for the files it installs).

  The same boot chain as an installed system, each stage verifying the next:
    firmware --(Microsoft UEFI CA)--> shim          (system/shim.bst)
    shim     --(MOK: bunix's key)---> systemd-boot  (system/esp.bst)
    systemd-boot --(via shim)-------> bunix-live.efi, a UKI: kernel,
                                      initramfs, command line (signed here)
  On each machine's first boot shim finds systemd-boot signed by a key it
  does not know yet and opens MokManager, where bunix.cer (on the EFI
  partition) is enrolled once.  No BIOS boot: the installed system is UEFI
  only too.

build-depends:
- bootstrap/build-env.bst
- base/zstd.bst
- base/cpio.bst
- base/xorriso.bst
- base/mtools.bst
- base/dosfstools.bst
# ukify, the EFI stub and systemd-sbsign (which brings the openssl tool)
- base/systemd.bst
- base/python-pefile.bst
- system/linux.bst
- filename: system/rootfs.bst
  config:
    location: /rootfs
# the signed boot files, and what bunix-install installs: this release's
# /usr, UKI and ESP files
- system/esp.bst
- filename: system/usr.bst
  config:
    location: /usr-partitions
- filename: system/uki.bst
  config:
    location: /uki

sources:
- kind: local
  path: files/install
  directory: install
# The Secure Boot signing key, kept out of version control -- only it, not
# keys/'s other keys.
- kind: local
  path: keys/secureboot.key
  directory: keys
- kind: local
  path: keys/secureboot.crt
  directory: keys
- kind: local
  path: files/branding/splash.bmp
  directory: branding

variables:
  # Both consoles; the last is the one /dev/console goes to.  The serial
  # port's shell starts only where the port exists (console-shell@ttyS0).
  # dm_verity.require_signatures=1: the kernel sets up no dm-verity device
  # whose root hash is not signed by a key it trusts -- extension images
  # included (docs/updates.md), whatever userspace is configured to accept.
  # quiet splash: no kernel or systemd messages on the screen, only the
  # boot splash (Plymouth, base/plymouth.bst), unless something fails.
  # plymouth.use-simpledrm: Plymouth draws on the firmware's framebuffer,
  # which it otherwise ignores, until the GPU's driver module loads.
  # plymouth.ignore-serial-consoles: with a serial console on the command
  # line Plymouth would show only its text mode, everywhere.
  cmdline: >-
    console=ttyS0,115200 console=tty0 quiet splash plymouth.use-simpledrm
    plymouth.ignore-serial-consoles dm_verity.require_signatures=1

config:
  build-commands:
  - |
    # BuildStream's artifacts keep no file modes but the executable bit;
    # these are the ones that matter, set on a copy of the root file system
    cp -a /rootfs rootfs
    cd rootfs
    # The live system has no /usr slots to update: no OS transfers, and the
    # extensions (gcc, rust, swift) come from its own release's directory
    # (an installed system takes the latest release's, together with the
    # new /usr).
    rm usr/lib/sysupdate.d/10-usr.transfer usr/lib/sysupdate.d/11-usr-verity.transfer \
       usr/lib/sysupdate.d/12-usr-verity-sig.transfer usr/lib/sysupdate.d/90-uki.transfer
    sed -i 's|^Path=https.*|Path=https://github.com/bunasys/bunix/releases/download/v%A/|' \
      usr/lib/sysupdate.d/5*-*.transfer
    # the installer, for the live system only (it reads the release from
    # the boot medium's install/)
    install -m 0755 %{build-root}/install/bunix-install usr/bin/bunix-install
    chmod 1777 tmp var/tmp
    chmod 0700 root
    chmod 0640 etc/shadow etc/gshadow

  - |
    # The root file system as the initramfs: a newc cpio archive, compressed
    # with zstd -19 (the kernel's decoder cannot take the larger windows of
    # the --ultra levels).
    set -o pipefail
    cd rootfs
    find . -print0 | cpio --null -o -H newc --owner=0:0 --quiet | zstd -19 -T0 -q > %{build-root}/initramfs.img

  - |
    # The live UKI.  --no-sign-kernel: the UKI's signature covers the
    # kernel inside (as system/uki.bst).
    mkdir -p tmp
    install -m 0600 keys/secureboot.key tmp/secureboot.key
    release=$(basename /usr/lib/modules/*)
    ukify build \
      --linux=/usr/lib/modules/$release/vmlinuz --uname=$release \
      --initrd=initramfs.img \
      --os-release=@/rootfs/usr/lib/os-release \
      --cmdline="%{cmdline}" \
      --splash=branding/splash.bmp \
      --stub=/usr/lib/systemd/boot/efi/linuxx64.efi.stub \
      --signtool=systemd-sbsign --no-sign-kernel \
      --secureboot-private-key=tmp/secureboot.key \
      --secureboot-certificate=keys/secureboot.crt \
      --output=bunix-live.efi

  - |
    # The EFI partition, which UEFI firmware boots: system/esp.bst's files
    # for a disk of bunix's own (shim as the default loader, which starts
    # systemd-boot as grubx64.efi next to it) and the live UKI, which
    # systemd-boot finds in EFI/Linux/.  Sized to its contents.
    mkdir -p esp/EFI/BOOT esp/EFI/Linux
    cp -a /usr/lib/bunix/esp/. esp/
    cp esp/EFI/bunix/systemd-bootx64.efi esp/EFI/BOOT/grubx64.efi
    cp esp/EFI/bunix/bunix.cer esp/bunix.cer
    cp bunix-live.efi esp/EFI/Linux/
    size_kib=$(( $(du -sk esp | cut -f1) + 8192 ))
    mkfs.fat -C -n BUNIX_EFI efi.img $size_kib
    mcopy -s -i efi.img esp/* ::/
    mdir -/ -i efi.img ::

  - |
    # The ISO 9660 file system: bunix-install's files, kept on the medium,
    # not in the initramfs, so they take no memory in the live system
    mkdir -p iso/install
    cp /usr-partitions/*.raw /uki/*.efi iso/install/
    cp -a /usr/lib/bunix/esp iso/install/esp
    cp esp/bunix.cer iso/

  - |
    # UEFI only: the EFI partition is appended to the image as a GPT
    # partition (for a USB stick) and is also the El Torito boot image (for
    # a CD)
    xorriso -as mkisofs -R -r -J -joliet-long -V BUNIX \
      -partition_offset 16 \
      -append_partition 2 0xef efi.img -appended_part_as_gpt \
      -e --interval:appended_partition_2:all:: -no-emul-boot \
      iso -o bunix-x86_64.iso

  install-commands:
  - install -D -m 0644 bunix-x86_64.iso %{install-root}/bunix-x86_64.iso
