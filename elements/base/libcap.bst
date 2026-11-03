kind: make
description: libcap -- POSIX capabilities library (systemd requires it)

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: kernel:linux/libs/security/linux-privs/libcap2/libcap-2.78.tar.xz
  ref: 0d621e562fd932ccf67b9660fb018e468a683d7b827541df27813228c996bb11

variables:
  # no Go bindings, no PAM module; RAISE_SETFCAP would run setcap on the
  # installed binary, which the sandbox does not allow
  make-args: >-
    prefix=%{prefix} lib=%{lib} SBINDIR=%{bindir}
    GOLANG=no PAM_CAP=no RAISE_SETFCAP=no

config:
  install-commands:
    (>):
    - rm %{install-root}%{libdir}/libcap.a %{install-root}%{libdir}/libpsx.a
