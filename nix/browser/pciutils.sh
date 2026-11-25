unpack $src
# No configure step: make with the directories and the options set, the
# same for the install, which otherwise builds again with the defaults.
# The shared libpci; LIBKMOD so that lspci -k names each device's driver;
# no udev hwdb (systemd is built without it), no compressed ID list, no
# DNS lookups of unknown IDs (as 0.4.0's element).
options="PREFIX=/usr SBINDIR=/usr/bin LIBDIR=/usr/lib/$triplet SHAREDIR=/usr/share MANDIR=/usr/share/man
    SHARED=yes ZLIB=no DNS=no HWDB=no LIBKMOD=yes"
make $options
make $options DESTDIR=$out install install-lib
# update-pciids replaces the ID list with one from the network, in /usr,
# which is read-only on a running system: the list is the package's
rm $out/usr/bin/update-pciids $out/usr/share/man/man8/update-pciids.8
