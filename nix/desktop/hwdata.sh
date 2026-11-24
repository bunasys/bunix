unpack $src
# Its configure is a small script of its own, and takes only the paths.
./configure --prefix=/usr --datadir=/usr/share
make DESTDIR=$out install
# pnp.ids, and the pkg-config file that tells a build where it is; the
# rest of the lists are other programs' (lspci and lsusb have their own)
find $out/usr/share/hwdata -type f ! -name pnp.ids -delete
rm -rf $out/usr/lib $out/etc
[ -s $out/usr/share/hwdata/pnp.ids ]
