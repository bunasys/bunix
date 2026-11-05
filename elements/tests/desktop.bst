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
    # (some firmware file names have spaces)
    find /usr -type f -print0 > files
    while IFS= read -r -d '' f; do
      is_elf=$(head -c 4 "$f" | tail -c 3)
      [ "$is_elf" = ELF ] || continue
      missing=$($loader --list "$f" 2>&1 | grep 'not found') || true
      if [ -n "$missing" ]; then
        echo "UNRESOLVED in $f: $missing"
        unresolved=1
      fi
    done < files
    exit $unresolved

  - |
    # Mesa: EGL, GLES and GBM, and the drivers -- all in libgallium, which
    # EGL loads by the driver's name (there are no dri/*_dri.so files
    # without GLX).  virtio_gpu is virgl's name; swrast is llvmpipe.
    cd /usr/lib/x86_64-linux-gnu
    ls libEGL.so.1 libGLESv2.so.2 libgbm.so.1 gbm/dri_gbm.so
    drivers=$(strings libgallium-*.so | grep -xE 'iris|crocus|radeonsi|virtio_gpu|swrast' | sort -u)
    for driver in iris crocus radeonsi virtio_gpu swrast; do
      echo "$drivers" | grep -qx $driver || { echo "no $driver driver"; exit 1; }
    done
    ls /usr/lib/x86_64-linux-gnu/libLLVM.so.*
    seatd -v
    libinput --version

  - |
    # The terminal starts (+version needs no display), and GTK's settings
    # schemas are compiled
    ghostty +version | head -3
    ls /usr/share/glib-2.0/schemas/gschemas.compiled
