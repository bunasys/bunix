kind: manual
description: |
  keyutils -- libkeyutils, the kernel keyring's library (mokutil reads the
  enrolled keys from the .platform keyring with it).  Only the library:
  keyctl and the request-key helpers are left out.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: kernel-git:linux/kernel/git/dhowells/keyutils.git/snapshot/keyutils-1.6.3.tar.gz
  ref: a61d5706136ae4c05bd48f86186bcfdbd88dd8bd5107e3e195c924cfc1b39bb4

variables:
  keyutils-make: >-
    make NO_ARLIB=1 PREFIX=%{prefix} LIBDIR=%{libdir} USRLIBDIR=%{libdir}
    BINDIR=%{bindir} SBINDIR=%{bindir} INCLUDEDIR=%{includedir}
    SHAREDIR=%{prefix}/share/keyutils MANDIR=%{prefix}/share/man ETCDIR=%{sysconfdir}
    CFLAGS="%{cflags}"

config:
  build-commands:
  - "%{keyutils-make}"
  install-commands:
  - "%{keyutils-make} DESTDIR=%{install-root} install"
  - |
    cd %{install-root}
    rm -rf .%{bindir} .%{sysconfdir} .%{prefix}/share
