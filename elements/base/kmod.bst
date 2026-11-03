kind: meson
description: |
  kmod -- loads kernel modules: modprobe, depmod, lsmod, modinfo, and the
  library udev uses to load the driver for each device it finds

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
# the modules are zstd-compressed (system/linux.bst); xz for modules built
# elsewhere
- base/zstd.bst
- base/xz.bst
# modinfo reads the modules' signatures (signer, hash) with libcrypto
- base/openssl.bst

sources:
- kind: tar
  url: kernel:linux/utils/kernel/kmod/kmod-34.3.tar.xz
  ref: 985554de49c21a58abd68c6cda2251384e1e5bb08b3b14c7f02b51f4c90c2958

variables:
  # UAPI.9: modules live under /usr/lib/modules
  meson-local: >-
    -Dmoduledir=/usr/lib/modules
    -Dzstd=enabled -Dxz=enabled -Dzlib=disabled -Dopenssl=enabled
    -Dmanpages=false -Ddocs=false -Dbuild-tests=false
    -Dbashcompletiondir=no -Dzshcompletiondir=no
