kind: manual
description: |
  BusyBox -- one binary for what no other package here provides (grep, sed,
  awk, tar, gzip, wget, ip, ping, traceroute, which, strings, lsof).  Which
  applets get a name in /usr/bin is decided when the system image is put
  together.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- base/bzip2.bst

sources:
- kind: tar
  url: busybox:busybox-1.38.0.tar.bz2
  ref: 34f9ea6ff8636f2c9241153b9114eefa9e65674a45318ae1ef95bb5f31c53bb2

config:
  configure-commands:
  - make defconfig
  # tc(8) does not build against current kernel headers, and the system has
  # no use for a second init or login stack: logins and passwords go
  # through PAM (util-linux's login, shadow's passwd and chpasswd).
  - |
    for sym in TC BOOTCHARTD INIT LINUXRC HALT POWEROFF REBOOT SULOGIN \
               GETTY INETD UDHCPD UDHCPC6 RUNSV SV \
               LOGIN PASSWD CHPASSWD SU ADDUSER DELUSER ADDGROUP DELGROUP; do
      sed -i "s/^CONFIG_$sym=y/# CONFIG_$sym is not set/" .config
    done
  - make oldconfig
  build-commands:
  - make busybox
  install-commands:
  - install -D -m 0755 busybox %{install-root}%{bindir}/busybox
