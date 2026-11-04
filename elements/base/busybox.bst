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
  # no use for a second init stack.  login and passwd are BusyBox's: the
  # console asks for root's password once it has one (files/rootfs,
  # console-shell).  passwd stores SHA-512 hashes, not the default MD5.
  - |
    for sym in TC BOOTCHARTD INIT LINUXRC HALT POWEROFF REBOOT SULOGIN \
               GETTY INETD UDHCPD UDHCPC6 RUNSV SV; do
      sed -i "s/^CONFIG_$sym=y/# CONFIG_$sym is not set/" .config
    done
    sed -i 's/^CONFIG_FEATURE_DEFAULT_PASSWD_ALGO=.*/CONFIG_FEATURE_DEFAULT_PASSWD_ALGO="sha512"/' .config
    grep -qx 'CONFIG_LOGIN=y' .config
    grep -qx 'CONFIG_USE_BB_CRYPT_SHA=y' .config
  - make oldconfig
  build-commands:
  - make busybox
  install-commands:
  - install -D -m 0755 busybox %{install-root}%{bindir}/busybox
