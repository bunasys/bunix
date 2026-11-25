unpack $src
# No configure step: make with the directories set.  The shared libpci;
# LIBKMOD so that lspci -k names each device's driver; no udev hwdb
# (systemd is built without it), no compressed ID list, no DNS lookups
# of unknown IDs (as 0.4.0's element).
directories="PREFIX=/usr SBINDIR=/usr/bin LIBDIR=/usr/lib/$triplet SHAREDIR=/usr/share MANDIR=/usr/share/man"
make $directories SHARED=yes ZLIB=no DNS=no HWDB=no LIBKMOD=yes
make $directories SHARED=yes ZLIB=no DNS=no HWDB=no LIBKMOD=yes DESTDIR=$out install install-lib
# update-pciids fetches the ID list from the network: the list comes
# with the package instead
rm -f $out/usr/bin/update-pciids $out/usr/share/pci.ids.gz
