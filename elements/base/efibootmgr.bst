kind: manual
description: |
  efibootmgr -- reads and writes the firmware's boot entries.  bunix-install
  creates the "bunix" entry with it: on a disk shared with Windows, shim's
  fallback (which creates it for the disk image) cannot run, because
  EFI/BOOT/BOOTX64.EFI there is Windows' own.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/efivar.bst

sources:
- kind: tar
  url: github:rhboot/efibootmgr/archive/refs/tags/18.tar.gz
  ref: 442867d12f8525034a404fc8af3036dba8e1fc970998af2486c3b940dfad0874

variables:
  # EFIDIR: the distribution's directory on the ESP, which efibootmgr
  # assumes when not given a loader path
  efibootmgr-make: >-
    make EFIDIR=bunix prefix=%{prefix} libdir=%{libdir} bindir=%{bindir}
    sbindir=%{bindir} CFLAGS="%{cflags}"

config:
  build-commands:
  - "%{efibootmgr-make} efibootmgr"
  install-commands:
  - install -D -m 0755 src/efibootmgr %{install-root}%{bindir}/efibootmgr
