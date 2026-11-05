kind: manual
description: |
  bunix_<release>.efi: the installed system's unified kernel image -- the
  kernel, CPU microcode, system/initrd.bst, os-release and the kernel
  command line in one
  EFI program, signed with the bunix Secure Boot key.  The command line
  holds usrhash=, the root hash of this release's /usr (system/usr.bst), so
  the signature covers which /usr the kernel accepts.

(@): include/release.yml

build-depends:
- bootstrap/build-env.bst
# ukify, the EFI stub, systemd-sbsign
- base/systemd.bst
- base/python-pefile.bst
- system/linux.bst
- filename: system/initrd.bst
  config:
    location: /initrd
# CPU microcode, which the stub hands to the kernel before the initrd
- filename: system/microcode.bst
  config:
    location: /microcode
- filename: system/usr.bst
  config:
    location: /usr-partitions
- filename: system/rootfs.bst
  config:
    location: /rootfs

sources:
- kind: local
  path: files/branding/splash.bmp
  directory: branding
- kind: local
  path: keys/secureboot.key
  directory: keys
- kind: local
  path: keys/secureboot.crt
  directory: keys

variables:
  # rw: the root partition is writable.  Both consoles; the last is the
  # one /dev/console (and the boot messages' main output) goes to.
  # dm_verity.require_signatures is not set here: /usr's root hash is
  # trusted because the signed UKI names it, without a signature of its own.
  # quiet splash: no kernel or systemd messages on the screen, only the
  # boot splash (Plymouth, base/plymouth.bst), unless something fails.
  # No plymouth.use-simpledrm: Plymouth waits for the GPU's driver, which
  # for Intel and QEMU's GPUs loads in the initrd (early KMS).  Drawing on
  # the firmware's framebuffer first made it switch devices when the
  # driver took over, between the firmware's logo and its own.
  # plymouth.ignore-serial-consoles: with a serial console on the command
  # line Plymouth would show only its text mode, everywhere.
  cmdline: rw console=ttyS0,115200 console=tty0 quiet splash
    plymouth.ignore-serial-consoles

config:
  build-commands:
  # --no-sign-kernel: the kernel inside needs no signature of its own, the
  # UKI's covers it (and ukify cannot check one with systemd-sbsign)
  - |
    release=$(basename /usr/lib/modules/*)
    # The kernel must come from the same build as /usr's modules: each
    # kernel build signs its modules with a new random key, and the kernel
    # rejects modules signed by another build's key.  Two builds of
    # system/linux.bst have the same cache key, so a cache shared between
    # build hosts (tools/cache-sync.sh) can pair one host's kernel with a
    # rootfs built from the other's -- 0.1.10 shipped that way, with no
    # network or GPU drivers on real hardware.
    if ! diff -rq /usr/lib/modules/$release/kernel /rootfs/usr/lib/modules/$release/kernel; then
      echo "the kernel and /usr's modules come from different builds of system/linux.bst" >&2
      exit 1
    fi
  - |
    mkdir -p tmp
    install -m 0600 keys/secureboot.key tmp/secureboot.key
    release=$(basename /usr/lib/modules/*)
    ukify build \
      --linux=/usr/lib/modules/$release/vmlinuz --uname=$release \
      --microcode=/microcode/microcode.cpio --initrd=/initrd/initrd.img \
      --os-release=@/rootfs/usr/lib/os-release \
      --cmdline="usrhash=$(cat /usr-partitions/usrhash) %{cmdline}" \
      --splash=branding/splash.bmp \
      --stub=/usr/lib/systemd/boot/efi/linuxx64.efi.stub \
      --signtool=systemd-sbsign --no-sign-kernel \
      --secureboot-private-key=tmp/secureboot.key \
      --secureboot-certificate=keys/secureboot.crt \
      --output=bunix_%{release-version}.efi
    ukify inspect bunix_%{release-version}.efi | head -30

  install-commands:
  - install -D -m 0644 bunix_%{release-version}.efi %{install-root}/bunix_%{release-version}.efi
