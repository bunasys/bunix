kind: manual
description: |
  bunix-x86_64.iso: the live system, for UEFI machines -- with Secure Boot
  on -- from a CD or written raw to a USB stick.  It boots the installed
  system's initrd, which mounts the release's signed /usr from the medium
  (the files bunix-install writes to disk, in install/) and an empty root
  file system in memory, filled from /usr as an installed system's first
  boot is (files/live).

  The same boot chain as an installed system, each stage verifying the next:
    firmware --(Microsoft UEFI CA)--> shim          (system/shim.bst)
    shim     --(MOK: bunix's key)---> systemd-boot  (system/esp.bst)
    systemd-boot --(via shim)-------> bunix-live.efi, a UKI: kernel,
                                      initrd, command line (signed here)
    initrd --(kernel: verity key)---> /usr, from the medium
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
# the extensions' transfer files, rewritten for the live system
- filename: system/rootfs.bst
  config:
    location: /rootfs
- filename: system/initrd.bst
  config:
    location: /initrd
# CPU microcode, as system/uki.bst
- filename: system/microcode.bst
  config:
    location: /microcode
# the signed boot files, and what bunix-install installs: this release's
# /usr, UKI and ESP files
- system/esp.bst
- filename: system/usr.bst
  config:
    location: /usr-partitions
- filename: system/uki.bst
  config:
    location: /uki
# the desktop extension, which bunix-install copies for a desktop install
- filename: sysext/desktop.bst
  config:
    location: /desktop

sources:
- kind: local
  path: files/live
  directory: live
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
  # No plymouth.use-simpledrm: Plymouth waits for the GPU's driver, which
  # for Intel and QEMU's GPUs loads in the initrd (early KMS).  Drawing on
  # the firmware's framebuffer first made it switch devices when the
  # driver took over, between the firmware's logo and its own.
  # plymouth.ignore-serial-consoles: with a serial console on the command
  # line Plymouth would show only its text mode, everywhere.
  # bunix.live, bunix.usrhash=: the initrd's live /usr (files/live); root
  # in memory, /usr the dm-verity device it sets up.
  cmdline: >-
    bunix.live root=tmpfs mount.usr=/dev/mapper/usr mount.usrfstype=erofs mount.usrflags=ro
    console=ttyS0,115200 console=tty0 quiet splash
    plymouth.ignore-serial-consoles dm_verity.require_signatures=1

config:
  build-commands:
  - |
    # The live additions to the installed initrd (files/live), with the
    # live system's /etc settings: the /usr transfers masked (there are no
    # /usr slots), the extensions taken from this release's directory (an
    # installed system takes the latest release's, together with the new
    # /usr)
    set -o pipefail
    settings=live/usr/lib/bunix/live-etc/sysupdate.d
    mkdir -p $settings
    for transfer in 10-usr 11-usr-verity 12-usr-verity-sig 90-uki; do
      ln -s /dev/null $settings/$transfer.transfer
    done
    for transfer in /rootfs/usr/lib/sysupdate.d/5*-*.transfer; do
      sed 's|^Path=https.*|Path=https://github.com/bunasys/bunix/releases/download/v%A/|' \
        $transfer > $settings/$(basename $transfer)
    done
    cd live
    find . -print0 | cpio --null -o -H newc --owner=0:0 --quiet | zstd -19 -q > %{build-root}/live.img

  - |
    # The live UKI: the installed system's kernel and initrd, the live
    # additions, and a command line naming this release's /usr.
    # --no-sign-kernel: the UKI's signature covers the kernel inside (as
    # system/uki.bst).  As there: the kernel must come from the same build
    # as /usr's modules, which system/usr.bst fingerprints.
    kernel_modules=$( (cd /usr/lib/modules && find . -name '*.ko*' -type f | sort | xargs sha256sum) \
      | sha256sum | cut -c1-64)
    usr_modules=$(cat /usr-partitions/modules.sha256)
    if [ "$kernel_modules" != "$usr_modules" ]; then
      echo "the kernel and /usr's modules come from different builds of system/linux.bst" >&2
      exit 1
    fi
    mkdir -p tmp
    install -m 0600 keys/secureboot.key tmp/secureboot.key
    release=$(basename /usr/lib/modules/*)
    ukify build \
      --linux=/usr/lib/modules/$release/vmlinuz --uname=$release \
      --microcode=/microcode/microcode.cpio --initrd=/initrd/initrd.img --initrd=live.img \
      --os-release=@/rootfs/usr/lib/os-release \
      --cmdline="bunix.usrhash=$(cat /usr-partitions/usrhash) %{cmdline}" \
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
    # The ISO 9660 file system: this release's /usr, UKI and ESP files,
    # which the live system mounts /usr from and bunix-install installs,
    # and the desktop extension
    mkdir -p iso/install
    cp /usr-partitions/*.raw /uki/*.efi /desktop/*.raw iso/install/
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
