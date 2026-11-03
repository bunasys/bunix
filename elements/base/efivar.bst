kind: manual
description: |
  efivar -- libraries for UEFI variables and device paths (libefivar,
  libefiboot), which efibootmgr is built on

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

sources:
- kind: tar
  url: github:rhboot/efivar/archive/refs/tags/39.tar.gz
  ref: c9edd15f2eeeea63232f3e669a48e992c7be9aff57ee22672ac31f5eca1609a6

variables:
  # ENABLE_DOCS=0: the man pages need mandoc
  efivar-make: >-
    make ENABLE_DOCS=0 PREFIX=%{prefix} LIBDIR=%{libdir} BINDIR=%{bindir}

config:
  build-commands:
  - "%{efivar-make}"
  install-commands:
  - "%{efivar-make} DESTDIR=%{install-root} install"
