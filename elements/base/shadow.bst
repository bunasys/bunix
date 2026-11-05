kind: autotools
description: |
  shadow -- the tools that manage users and groups: useradd, usermod,
  userdel, groupadd, groupmod, groupdel, chage, and passwd and chpasswd,
  which set passwords through PAM (files/rootfs/usr/lib/pam.d).  passwd is
  setuid root, set in system/usr.bst (artifacts keep no setuid bits).
  Its own login and su, chfn/chsh, newgrp, lastlog and faillog are left
  out (util-linux's login, run0).  /etc/login.defs and /etc/default/useradd
  reach installed systems through /usr/share/factory/etc.

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/libxcrypt.bst
- base/linux-pam.bst
# logind: userdel and usermod refuse to change a user who is logged in
- base/systemd.bst

sources:
- kind: tar
  url: github:shadow-maint/shadow/releases/download/4.20.3/shadow-4.20.3.tar.xz
  ref: 623be9429f64fa2165bfc5957c6a642ec309c5cf23c0d53855c99f7591922297

variables:
  conf-local: >-
    --sysconfdir=/etc --disable-static --disable-nls --disable-man
    --with-libpam --with-yescrypt --without-su --disable-subordinate-ids
    --without-audit --without-selinux --without-acl --without-btrfs --without-tcb
    --without-sssd --without-libbsd --without-skey

config:
  install-commands:
    (>):
    # its admin tools go to /usr/sbin, which this system does not have
    - |
      mv %{install-root}/usr/sbin/* %{install-root}%{bindir}/
      rmdir %{install-root}/usr/sbin
    - |
      cd %{install-root}
      for program in login su nologin faillog lastlog chfn chsh newgrp sg expiry \
                     vipw vigr pwconv pwunconv grpconv grpunconv logoutd newusers \
                     getsubids newuidmap newgidmap; do
        rm -f usr/bin/$program
      done
      # PAM rules come from files/rootfs/usr/lib/pam.d, not /etc/pam.d
      rm -rf etc/pam.d
      # bunix's account defaults: a group per user, a private home made at
      # creation, and fish, root's shell too (base/fish.bst,
      # files/rootfs/usr/lib/sysusers.d/00-bunix-root.conf)
      sed -i -e 's/^#\?ENCRYPT_METHOD.*/ENCRYPT_METHOD YESCRYPT/' \
             -e 's/^#\?CREATE_HOME.*/CREATE_HOME yes/' \
             -e 's/^#\?HOME_MODE.*/HOME_MODE 0700/' etc/login.defs
      mkdir -p etc/default etc/skel
      printf 'HOME=/home\nINACTIVE=-1\nEXPIRE=\nSHELL=/usr/bin/fish\nSKEL=/etc/skel\nCREATE_MAIL_SPOOL=no\n' \
        > etc/default/useradd
      grep -E '^(ENCRYPT_METHOD|CREATE_HOME|HOME_MODE|USERGROUPS_ENAB)' etc/login.defs
      ls usr/bin
