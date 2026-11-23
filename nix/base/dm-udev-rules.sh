unpack $src
# Only the device mapper's udev rules, of LVM2's source; the element's
# arguments.  --without-systemd: the rules need none of it.
./configure --prefix=/usr --libdir=/usr/lib/$triplet --with-usrlibdir=/usr/lib/$triplet \
    --sbindir=/usr/bin --with-usrsbindir=/usr/bin --sysconfdir=/etc \
    --enable-udev_rules --with-udevdir=/usr/lib/udev/rules.d \
    --disable-readline --disable-selinux --disable-blkid_wiping --without-blkid \
    --without-libaio --without-systemd --disable-nls
make -C udev
make -C udev DESTDIR=$out install_device-mapper
