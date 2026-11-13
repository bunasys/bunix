kind: autotools
description: |
  util-linux -- libmount, libblkid and libuuid for systemd, and the programs
  (mount, lsblk, fdisk, dmesg, kill, more, rfkill, ...)

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/ncurses.bst
- base/readline.bst

sources:
- kind: tar
  url: kernel:linux/utils/util-linux/v2.42/util-linux-2.42.4.tar.xz
  ref: fbd62a100ab7bb8746ba0661255c3c48185b1e9021507c624da01fbc696330ec

variables:
  # Left out: what needs PAM (login, su, runuser, chfn/chsh), libcrypt
  # (newgrp, sulogin), libcap-ng (setpriv), sqlite (lastlog2), a running
  # systemd (uuidd; systemd itself is built on util-linux), and the obsolete
  # cramfs tools.  usrlib_execdir is where util-linux puts its libraries.
  # setuid/chown happen at image composition, not in the sandbox.
  conf-local: >-
    usrlib_execdir=%{libdir}
    --disable-static --disable-nls --disable-asciidoc --disable-poman
    --disable-login --disable-su --disable-runuser --disable-chfn-chsh
    --disable-newgrp --disable-sulogin --disable-setpriv --disable-uuidd
    --disable-cramfs --disable-liblastlog2 --disable-pam-lastlog2
    --disable-pylibmount --disable-bash-completion
    --disable-makeinstall-chown --disable-makeinstall-setuid
    --without-python --without-systemd --without-udev --without-libmagic
    --without-econf --without-cryptsetup --without-audit --without-selinux
    --without-smack --without-btrfs --with-readline

config:
  install-commands:
    (>):
    # a few programs go to /usr/sbin whatever --sbindir says
    - |
      if [ -d %{install-root}/usr/sbin ]; then
        mv %{install-root}/usr/sbin/* %{install-root}%{bindir}/
        rmdir %{install-root}/usr/sbin
      fi
