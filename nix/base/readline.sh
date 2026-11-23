unpack $src
for fix in $patches; do
    patch -p0 < $fix
done

./configure $configure_for_usr --with-curses --disable-static --disable-install-examples
# SHLIB_LIBS: the library records that it needs the terminal library, so
# that a program linking readline alone still finds it
make SHLIB_LIBS=-ltinfo
make SHLIB_LIBS=-ltinfo DESTDIR=$out install
