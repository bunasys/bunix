kind: manual
description: |
  The desktop extension as it is on a running system: the root file
  system with sysext/desktop-tree.bst over it, and no other extension.
  Every program and library in it finds the libraries it needs, and Mesa
  has its drivers.

build-depends:
- system/rootfs.bst
- sysext/desktop-tree.bst

config:
  build-commands:
  - |
    loader=/usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2
    unresolved=0
    for f in $(find /usr -type f); do
      is_elf=$(head -c 4 "$f" | tail -c 3)
      [ "$is_elf" = ELF ] || continue
      missing=$($loader --list "$f" 2>&1 | grep 'not found') || true
      if [ -n "$missing" ]; then
        echo "UNRESOLVED in $f: $missing"
        unresolved=1
      fi
    done
    exit $unresolved

  - |
    # Mesa: EGL and GBM, and the drivers (one library, linked per driver)
    for lib in libEGL.so.1 libGLESv2.so.2 libgbm.so.1 libgallium-*.so; do
      ls /usr/lib/x86_64-linux-gnu/$lib
    done
    # virtio_gpu is virgl's name; swrast is llvmpipe
    for driver in iris crocus radeonsi virtio_gpu swrast; do
      test -e /usr/lib/x86_64-linux-gnu/dri/${driver}_dri.so || { echo "no $driver driver"; exit 1; }
    done
    test -e /usr/lib/x86_64-linux-gnu/gbm/dri_gbm.so
    ls /usr/lib/x86_64-linux-gnu/libLLVM.so.*
    seatd -v
    libinput --version
