kind: manual
description: |
  shim and MokManager for x86_64 UEFI, signed by Microsoft: Debian's builds,
  the only binaries in the boot chain not built here.  Firmware with Secure
  Boot on trusts Microsoft's UEFI CA, and Microsoft signs shim, not what a
  distribution builds itself.  shim in turn trusts the keys enrolled with
  MokManager, which is where bunix's own key goes.

build-depends:
- bootstrap/build-env.bst

# snapshot.debian.org keeps every file the Debian archive ever had, so these
# links keep working after Debian moves on to newer versions
sources:
- kind: remote
  url: snapshot:20260622T023321Z/pool/main/s/shim-signed/shim-signed_1.51+16.1-2_amd64.deb
  filename: shim-signed.deb
  ref: 993868c31cca3eab054a0c51c124a4a8b3904f49fb002feb4b09cb9415200e74
- kind: remote
  url: snapshot:20260403T203237Z/pool/main/s/shim-helpers-amd64-signed/shim-helpers-amd64-signed_1+16.1+2_amd64.deb
  filename: shim-helpers.deb
  ref: 6a6d340710ffc067198af33785d1e04836b2cc0d259ec4b080a06604d333a8cb

config:
  install-commands:
  - |
    # a .deb is an ar archive; the files are in its data.tar.xz
    for deb in shim-signed shim-helpers; do
      mkdir $deb && cd $deb
      ar x ../$deb.deb
      tar -xf data.tar.xz
      cd ..
    done
  - install -D -m 0644 shim-signed/usr/lib/shim/shimx64.efi.signed %{install-root}/usr/lib/shim/shimx64.efi
  - install -D -m 0644 shim-helpers/usr/lib/shim/mmx64.efi.signed %{install-root}/usr/lib/shim/mmx64.efi
  # fallback: run by shim from EFI/BOOT, it creates firmware boot entries
  # from EFI/*/BOOTX64.CSV (system/disk.bst)
  - install -D -m 0644 shim-helpers/usr/lib/shim/fbx64.efi.signed %{install-root}/usr/lib/shim/fbx64.efi
