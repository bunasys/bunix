kind: manual
description: |
  libdevmapper and dmsetup, from LVM2 -- cryptsetup sets up dm-verity
  through this library.  LVM itself is not built.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

sources:
- kind: tar
  url: sourceware:lvm2/LVM2.2.03.44.tgz
  ref: 42f829927d2d459f5733fcdb38a5bf2455a8b84072193092450a9c69d6596eca

config:
  # No udev synchronisation: libdevmapper is built before systemd's libudev,
  # and systemd's own verity setup does not use it.
  configure-commands:
  - |
    ./configure --prefix=%{prefix} --libdir=%{libdir} --with-usrlibdir=%{libdir} \
      --sbindir=%{bindir} --with-usrsbindir=%{bindir} --sysconfdir=/etc \
      --enable-pkgconfig --disable-readline --disable-selinux \
      --disable-blkid_wiping --without-blkid --without-libaio \
      --without-systemd --without-udev --disable-nls
  build-commands:
  - make device-mapper
  # install_device-mapper relinks dmsetup, and in parallel it races with
  # itself (dmsetup linked without the object that has main)
  install-commands:
  - make -j1 DESTDIR=%{install-root} install_device-mapper
