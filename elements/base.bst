kind: stack
description: |
  The base system's packages.  Build tools
  (cmake, meson, perl, ...) are not in it; they reach the system only if
  something here depends on them.  glibc and gcc's runtime libraries come
  from the bootstrap and are added when the image is put together.

depends:
- base/bash.bst
- base/bind.bst
- base/busybox.bst
- base/ca-certificates.bst
- base/curl.bst
- base/dbus.bst
- base/dm-udev-rules.bst
- base/dosfstools.bst
- base/e2fsprogs.bst
- base/efibootmgr.bst
- base/fish.bst
- base/fonts-arabic.bst
- base/grep.bst
- base/htop.bst
- base/iproute2.bst
- base/iwd.bst
- base/kmod.bst
- base/less.bst
- base/mokutil.bst
- base/nawa.bst
- base/neovim.bst
- base/net-tools.bst
- base/nftables.bst
- base/nvme-cli.bst
- base/openssh.bst
- base/pciutils.bst
- base/plymouth.bst
- base/polkit.bst
- base/procps-ng.bst
- base/psmisc.bst
- base/ripgrep.bst
- base/rsync.bst
- base/smartmontools.bst
- base/shadow.bst
- base/sqv.bst
- base/systemd.bst
- base/tar.bst
- base/tzdata.bst
- base/usbutils.bst
- base/util-linux.bst
- base/util-linux-login.bst
- base/uutils-coreutils.bst
- base/uutils-findutils.bst
- base/wireless-regdb.bst
