kind: manual
description: |
  The installed system's boot files for the EFI system partition, signed:
  what system/disk.bst puts on its ESP and bunix-install (on the ISO) copies
  to the ESP of the disk it installs to.  Installed under /usr/lib/bunix/esp:

    EFI/bunix/shimx64.efi, mmx64.efi
                     shim (Microsoft-signed) and MokManager; the "bunix"
                     firmware boot entry starts shim, telling it to start
                     systemd-boot
    EFI/bunix/systemd-bootx64.efi
                     systemd-boot, signed with the bunix Secure Boot key;
                     it boots the newest UKI in EFI/Linux/ (on the ESP or the
                     XBOOTLDR partition) and lists Windows if it is there.
                     In bunix's own directory, not EFI/systemd/: on an ESP
                     shared with another distribution, that one is theirs.
    EFI/bunix/grubx64.efi
                     the same systemd-boot, under the name shim starts when
                     its boot entry names no loader.  The entry does name
                     systemd-boot, but some PCs' firmware does not pass a
                     boot entry's options on to shim (found on real hardware;
                     QEMU does), and shim then looks for grubx64.efi.
    EFI/bunix/BOOTX64.CSV
                     the boot entry, for shim's fallback
    EFI/bunix/bunix.cer
                     the bunix Secure Boot certificate, for MokManager's
                     "Enroll key from disk"
    EFI/BOOT/BOOTX64.EFI, fbx64.efi, mmx64.efi
                     the default loader -- shim, which runs fallback -- for a
                     disk with no boot entry yet.  Only for an ESP bunix has
                     to itself: on one shared with Windows this is Windows'.
    loader/loader.conf

build-depends:
- bootstrap/build-env.bst
# systemd-boot and systemd-sbsign (which brings the openssl tool)
- base/systemd.bst
- system/shim.bst

sources:
- kind: local
  path: keys/secureboot.key
  directory: keys
- kind: local
  path: keys/secureboot.crt
  directory: keys

variables:
  esp: "%{install-root}/usr/lib/bunix/esp"

config:
  install-commands:
  - |
    mkdir -p tmp %{esp}/EFI/BOOT %{esp}/EFI/bunix %{esp}/loader
    install -m 0600 keys/secureboot.key tmp/secureboot.key
    cp /usr/lib/shim/shimx64.efi %{esp}/EFI/BOOT/BOOTX64.EFI
    cp /usr/lib/shim/fbx64.efi /usr/lib/shim/mmx64.efi %{esp}/EFI/BOOT/
    cp /usr/lib/shim/shimx64.efi /usr/lib/shim/mmx64.efi %{esp}/EFI/bunix/
    # fallback reads UCS-2: file name, label, options (shim's second stage),
    # description
    python3 -c 'open("%{esp}/EFI/bunix/BOOTX64.CSV", "w", encoding="utf-16").write(
        "shimx64.efi,bunix,\\EFI\\bunix\\systemd-bootx64.efi ,bunix\n")'
    /usr/lib/systemd/systemd-sbsign sign --private-key=tmp/secureboot.key \
      --certificate=keys/secureboot.crt --output=%{esp}/EFI/bunix/systemd-bootx64.efi \
      /usr/lib/systemd/boot/efi/systemd-bootx64.efi
    cp %{esp}/EFI/bunix/systemd-bootx64.efi %{esp}/EFI/bunix/grubx64.efi
    openssl x509 -in keys/secureboot.crt -outform DER -out %{esp}/EFI/bunix/bunix.cer
    # The menu stays hidden -- the boot goes straight from the firmware's
    # logo to bunix's (hold Space while booting to see it) -- and lists only
    # bunix: no entries for other systems' loaders.  Windows is started from
    # the firmware's boot menu (docs/install.md).
    printf 'timeout 0\nconsole-mode keep\nauto-entries no\n' > %{esp}/loader/loader.conf
    find %{esp} -type f | sort
