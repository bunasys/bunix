kind: manual
description: |
  device-mapper's udev rules, from LVM2: they name /dev/mapper/* devices and
  tell systemd when one is ready.  Without them systemd waits forever for
  /dev/mapper/usr, the installed system's dm-verity /usr.  A package of its
  own (same source as base/device-mapper.bst) so that adding the rules does
  not rebuild everything that links libdevmapper.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

runtime-depends:
# the rules run dmsetup
- base/device-mapper.bst

sources:
- kind: tar
  url: sourceware:lvm2/LVM2.2.03.44.tgz
  ref: 42f829927d2d459f5733fcdb38a5bf2455a8b84072193092450a9c69d6596eca

config:
  configure-commands:
  - |
    ./configure --prefix=%{prefix} --libdir=%{libdir} --with-usrlibdir=%{libdir} \
      --sbindir=%{bindir} --with-usrsbindir=%{bindir} --sysconfdir=/etc \
      --enable-udev_rules --with-udevdir=/usr/lib/udev/rules.d \
      --disable-readline --disable-selinux --disable-blkid_wiping --without-blkid \
      --without-libaio --without-systemd --disable-nls
  build-commands:
  - make -C udev
  install-commands:
  - make -C udev DESTDIR=%{install-root} install_device-mapper
  - ls %{install-root}/usr/lib/udev/rules.d
