unpack $src
# The element's arguments, without systemd's units: nothing here reads
# them yet.  The tarball has its own copy of ell, the library iwd is
# written on; the manual pages would need rst2man.
./configure $configure_for_usr --libexecdir=/usr/lib/iwd \
    --enable-client --disable-manual-pages --disable-systemd-service \
    --with-dbus-datadir=/usr/share
make
make DESTDIR=$out install
# /var is the running system's, not a package's
rm -rf $out/var
