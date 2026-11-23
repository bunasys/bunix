unpack $src
# Only the device mapper's library and dmsetup, of LVM2's source; LVM
# itself is not built.  The element's arguments.
./configure --prefix=/usr --libdir=/usr/lib/$triplet --with-usrlibdir=/usr/lib/$triplet \
    --sbindir=/usr/bin --with-usrsbindir=/usr/bin --sysconfdir=/etc \
    --enable-pkgconfig --disable-readline --disable-selinux \
    --disable-blkid_wiping --without-blkid --without-libaio \
    --without-systemd --without-udev --disable-nls
make device-mapper
# -j1: the install steps write the same directories at once otherwise
make -j1 DESTDIR=$out install_device-mapper
# a script that unmounts and deactivates whole stacks of devices, with
# LVM's and others' programs, which are not here
rm $out/usr/bin/blkdeactivate
