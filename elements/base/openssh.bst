kind: autotools
description: |
  OpenSSH -- ssh, scp, sftp, ssh-keygen and ssh-agent, and sshd, which is
  installed but off until an admin enables it (sshd.service): keys only,
  no passwords (files/rootfs/etc/ssh/sshd_config).  With PAM for accounts
  and sessions only (files/rootfs/usr/lib/pam.d/sshd), so SSH logins are
  logind sessions; sshd tells systemd when it is ready.

build-depends:
- bootstrap/build-env.bst

depends:
- base/openssl.bst
- base/linux-pam.bst
- base/zlib.bst

sources:
- kind: tar
  url: openbsd:OpenSSH/portable/openssh-10.6p1.tar.gz
  ref: a9dc9565dffe8640f64d863cd29a32bc4a3dbdec0566a7fc44c5d6ee767d5f39

variables:
  # UAPI.9: helpers (sftp-server, sshd-session, ...) in /usr/lib/ssh; the
  # privilege separation directory, empty and root's, in read-only /usr
  conf-local: >-
    --sysconfdir=/etc/ssh --libexecdir=/usr/lib/ssh
    --with-privsep-path=/usr/share/empty.sshd --with-privsep-user=sshd
    --with-pid-dir=/run --with-default-path=/usr/bin --with-superuser-path=/usr/bin
    --disable-lastlog --disable-utmp --disable-utmpx --disable-wtmp --disable-wtmpx
    --disable-strip --with-pam

config:
  install-commands:
  # install-nokeys: host keys are made on each machine, when sshd first starts
  - make -j1 DESTDIR=%{install-root} install-nokeys
  - install -d %{install-root}/usr/share/empty.sshd
