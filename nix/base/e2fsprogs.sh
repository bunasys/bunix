unpack $src
# The element's arguments: libuuid and libblkid are util-linux's; no FUSE,
# no translations, nothing for cron, systemd or udev.
./configure $configure_for_usr \
    --disable-static --disable-nls --disable-libuuid --disable-libblkid \
    --disable-uuidd --disable-fsck --disable-fuse2fs --disable-e2initrd-helper \
    --enable-elf-shlibs --with-crond-dir=no --with-systemd-unit-dir=no \
    --with-udev-rules-dir=no
make
make DESTDIR=$out install
# the libraries' headers and .so links
make DESTDIR=$out install-libs
# e2scrub checks a file system from a snapshot that LVM makes of it, and
# there is no LVM here.
rm $out/usr/bin/e2scrub $out/usr/bin/e2scrub_all $out/etc/e2scrub.conf \
    $out/usr/share/man/man8/e2scrub.8 $out/usr/share/man/man8/e2scrub_all.8
