kind: autotools
description: |
  login and runuser from util-linux, with PAM: the console's login prompt
  (console-shell@.service), whose sessions logind now knows, and runuser,
  root's way to run something as another user.  A separate build from the
  same source as base/util-linux.bst, which systemd itself is built on:
  PAM there would rebuild most of the system.  No su: run0 is the way up.

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/linux-pam.bst

sources:
- kind: tar
  url: kernel:linux/utils/util-linux/v2.42/util-linux-2.42.4.tar.xz
  ref: fbd62a100ab7bb8746ba0661255c3c48185b1e9021507c624da01fbc696330ec

variables:
  conf-local: >-
    --disable-all-programs --enable-login --enable-runuser
    --disable-static --disable-nls --disable-asciidoc --disable-poman
    --disable-bash-completion --disable-makeinstall-chown --disable-makeinstall-setuid
    --without-python --without-systemd --without-udev --without-libmagic
    --without-econf --without-audit --without-selinux --without-btrfs --without-readline

config:
  install-commands:
    (>):
    # (as base/util-linux.bst) a few programs go to /usr/sbin whatever
    # --sbindir says, and the directory is made even when empty
    - |
      if [ -d %{install-root}/usr/sbin ]; then
        find %{install-root}/usr/sbin -mindepth 1 -maxdepth 1 -exec mv {} %{install-root}%{bindir}/ \;
        rmdir %{install-root}/usr/sbin
      fi
