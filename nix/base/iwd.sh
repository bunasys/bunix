unpack $src
# The element's arguments.  The tarball has its own copy of ell, the
# library iwd is written on; the manual pages would need rst2man.
./configure $configure_for_usr --libexecdir=/usr/lib/iwd \
    --enable-client --disable-manual-pages --enable-systemd-service \
    --with-systemd-unitdir=/usr/lib/systemd/system \
    --with-systemd-networkdir=/usr/lib/systemd/network \
    --with-systemd-modloaddir=/usr/lib/modules-load.d \
    --with-dbus-datadir=/usr/share \
    --with-dbus-busdir=/usr/share/dbus-1/system-services
make
make DESTDIR=$out install
# /var is the running system's, not a package's
rm -rf $out/var
