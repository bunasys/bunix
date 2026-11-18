unpack $src

# One library with wide characters, under the plain names (libncurses.so,
# <curses.h>), and its .pc files for pkg-config.
./configure $configure_for_usr \
    --with-shared --without-normal --without-debug \
    --enable-widec --disable-lib-suffixes --enable-overwrite \
    --enable-pc-files --with-pkg-config-libdir=/usr/lib/$triplet/pkgconfig \
    --without-cxx --without-cxx-binding --without-ada --without-manpages \
    --without-tests --disable-stripping
make
make DESTDIR=$out install

# The other names programs ask for it by: libtinfo, and the names with a
# `w` that a wide-character build would have had.
cd $out/usr/lib/$triplet
echo 'INPUT(-lncurses)' > libtinfo.so
ln -s ncurses.pc pkgconfig/tinfo.pc
for library in ncurses panel menu form; do
    ln -s lib$library.so lib${library}w.so
    ln -s $library.pc pkgconfig/${library}w.pc
done
ln -s . $out/usr/include/ncursesw
