unpack $src
# where pkg-config looks for .pc files, and the directories it need not
# name to the compiler, which looks there anyway
./configure $configure_for_usr --disable-static \
    --with-pkg-config-dir=/usr/lib/$triplet/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig \
    --with-system-libdir=/usr/lib/$triplet:/usr/lib \
    --with-system-includedir=/usr/include
make
make DESTDIR=$out install
ln -s pkgconf $out/usr/bin/pkg-config
