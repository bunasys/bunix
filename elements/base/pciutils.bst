kind: manual
description: |
  pciutils -- lspci and setpci, and libpci.  lspci names devices from the
  PCI ID list shipped with it.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/kmod.bst

sources:
- kind: tar
  url: kernel:software/utils/pciutils/pciutils-3.15.0.tar.xz
  ref: c02940f430841ecf158d5d9a50007afc4d5353c8678a2455003ca0b2c4e9f5ff

variables:
  # LIBKMOD: lspci -k shows the driver each device can use.  No udev hwdb
  # (systemd is built without it); no compressed ID list, no DNS lookups
  # of unknown IDs.
  pciutils-make: >-
    make PREFIX=%{prefix} SBINDIR=%{bindir} LIBDIR=%{libdir} SHAREDIR=%{prefix}/share
    MANDIR=%{prefix}/share/man SHARED=yes ZLIB=no DNS=no HWDB=no LIBKMOD=yes
    OPT="%{cflags}"

config:
  build-commands:
  - "%{pciutils-make}"
  install-commands:
  - "%{pciutils-make} DESTDIR=%{install-root} install install-lib"
  - rm -f %{install-root}%{bindir}/update-pciids %{install-root}%{prefix}/share/pci.ids.gz
