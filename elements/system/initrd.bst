kind: manual
description: |
  The installed system's initrd (docs/updates.md, step 2), made from the
  root file system's own files: systemd and udev with their units and
  generators, which find /usr by the usrhash= on the kernel command line
  (dm-verity) and the root partition by its GPT type; systemd-repart and
  mkfs.ext4, which create the root partition on first boot; fsck; bash
  for the emergency shell; and the GPU drivers with their firmware, so the
  screen has its own resolution from the start (the boot splash too).  A newc cpio archive, zstd-compressed, for
  system/uki.bst.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- base/zstd.bst
- base/cpio.bst
- filename: system/rootfs.bst
  config:
    location: /rootfs

config:
  install-commands:
  - |
    # systemd's tree (PID 1, helpers, units, generators), udev's rules,
    # what tmpfiles and sysusers read, and the programs the units run
    mkdir -p initrd
    cd /rootfs
    cp -a --parents usr/lib/systemd usr/lib/udev usr/lib/tmpfiles.d \
          usr/lib/sysusers.d usr/lib/os-release %{build-root}/initrd/
    # not udev's hardware database: 12 MB of keyboard fixes and device
    # names, which the initrd does not need, in an image the firmware reads
    # and hashes at every boot
    rm -rf %{build-root}/initrd/usr/lib/udev/hwdb.bin %{build-root}/initrd/usr/lib/udev/hwdb.d
    # The boot splash (base/plymouth.bst): its daemon, plugins and theme.
    # Its units came with usr/lib/systemd above.
    cp -a --parents usr/lib/plymouth usr/lib/%{triplet}/plymouth usr/share/plymouth \
          %{build-root}/initrd/
    for program in systemctl journalctl udevadm systemd-tmpfiles systemd-sysusers \
                   systemd-repart systemd-escape systemd-ask-password mount umount \
                   blkid fsck mke2fs mkfs.ext4 e2fsck fsck.ext4 bash sh busybox \
                   dmesg dmsetup losetup systemd-dissect plymouth plymouthd; do
      cp -a --parents usr/bin/$program %{build-root}/initrd/
      # follow links (sh -> bash, ls -> coreutils, ...) to the program itself
      target=$(readlink usr/bin/$program || true)
      if [ -n "$target" ]; then
        cp -a --parents usr/bin/$target %{build-root}/initrd/
      fi
    done
    # The full system's services stay out: they would only fail here.
    cd %{build-root}/initrd/usr/lib/systemd
    for name in networkd resolved timesyncd sysupdate sysupdated importd pull \
                boot-check-no-failures; do
      rm -rf systemd-$name system/systemd-$name*
    done
    rm -rf system/dbus* system/iwd* system/console-shell*
    find system -xtype l -delete
    # BusyBox's tools for the emergency shell -- ls and cat too: uutils'
    # coreutils would add 14 MB that the firmware reads and hashes at boot
    cd %{build-root}/initrd/usr/bin
    for applet in ls cat grep head tail sed awk cut less ps tr mkdir mountpoint cp mv rm ln chmod; do
      [ -e $applet ] || ln -s busybox $applet
    done
    cd /rootfs
    # users and groups udev rules and units name (disk, systemd-journal, ...)
    mkdir -p %{build-root}/initrd/etc
    cp -a etc/passwd etc/group etc/nsswitch.conf %{build-root}/initrd/etc/

  - |
    # Early KMS: the GPU drivers (and the modules they need), loaded by udev
    # here, so the GPU's driver takes the screen over from the firmware's
    # framebuffer, with the panel's own resolution, before the boot splash
    # starts -- not once /usr is mounted, near the end of boot.  With their
    # firmware: xe does not start without it.  Intel's and the VMs' only:
    # AMD's firmware is 46 MB, and the firmware reads the whole UKI before
    # the kernel starts (about 10 MB/s on a test machine), so amdgpu and
    # radeon load from /usr, as every other driver does.
    release=$(basename /rootfs/usr/lib/modules/*)
    # the image's own kmod, by the name of the tool it should act as
    run_kmod() {
      tool=$1; shift
      LD_LIBRARY_PATH=/rootfs%{libdir} /rootfs%{libdir}/ld-linux-x86-64.so.2 \
        --argv0 $tool /rootfs/usr/bin/kmod "$@"
    }
    run_kmod modprobe --dirname=/rootfs --set-version=$release --show-depends --all \
      i915 xe bochs virtio-gpu |
      sed -n 's|^insmod /rootfs/||p' | sed 's| .*||' | sort -u > gpu-modules
    cd /rootfs
    cp -a --parents $(cat %{build-root}/gpu-modules) %{build-root}/initrd/
    cp -a --parents usr/lib/modules/$release/modules.order \
          usr/lib/modules/$release/modules.builtin usr/lib/modules/$release/modules.builtin.modinfo \
          %{build-root}/initrd/
    run_kmod depmod --basedir=%{build-root}/initrd $release
    cp -a --parents usr/lib/firmware/i915 usr/lib/firmware/xe %{build-root}/initrd/
    wc -l < %{build-root}/gpu-modules

  - |
    # Libraries: what systemd loads at run time with dlopen() --
    # libcryptsetup for dm-verity, libfdisk for repart, OpenSSL for verity
    # signatures, NSS for users, libkmod (udev loads the GPU's driver), the
    # TPM libraries (boot phase measurements), libacl (udev's uaccess rule,
    # which otherwise logs an error for every seat device) -- and everything all the programs and
    # libraries here link, resolved by the image's own loader.
    loader=/rootfs%{libdir}/ld-linux-x86-64.so.2
    libs=/rootfs%{libdir}
    cd initrd
    mkdir -p .%{libdir}
    for lib in $(cd $libs && ls ld-linux-x86-64.so.2 libcryptsetup.so.* libdevmapper.so.* \
                               libjson-c.so.* libfdisk.so.* libcrypto.so.* libnss_files.so.* \
                               libkmod.so.* libtss2-*.so.* libacl.so.*); do
      cp -a $libs/$lib .%{libdir}/
    done
    find . -type f | while read -r f; do
      case $(file -b "$f") in ELF*) ;; *) continue ;; esac
      LD_LIBRARY_PATH=$libs:$libs/systemd $loader --list "$f" |
        sed -n 's|.* => /rootfs\(/[^ ]*\) .*|\1|p'
    done | sort -u > %{build-root}/needed-libraries
    while read -r lib; do
      mkdir -p "$(dirname ".$lib")"
      cp -L "/rootfs$lib" ".$lib"
    done < %{build-root}/needed-libraries
    wc -l < %{build-root}/needed-libraries

  - |
    # The initrd's own identity and layout: systemd knows it is in an initrd
    # by /etc/initrd-release, and boots initrd.target there.
    cd initrd
    cp usr/lib/os-release etc/initrd-release
    ln -s usr/bin bin
    ln -s usr/bin sbin
    ln -s usr/lib lib
    ln -s usr/lib/%{triplet} lib64
    ln -s usr/lib/systemd/systemd init
    mkdir -p proc sys dev run tmp var/tmp sysroot sysusr/usr root
    # The emergency and rescue shells: bunix has no sulogin, so they are a
    # plain root bash on the console.
    for unit in emergency rescue; do
      mkdir -p usr/lib/systemd/system/$unit.service.d
      printf '[Service]\nExecStart=\nExecStart=-/usr/bin/bash -l\n' \
        > usr/lib/systemd/system/$unit.service.d/bunix.conf
    done
    du -sh .

  - |
    set -o pipefail
    cd initrd
    find . -print0 | cpio --null -o -H newc --owner=0:0 --quiet | zstd -19 -T0 -q \
      > %{install-root}/initrd.img
    ls -l %{install-root}/initrd.img
