unpack $src
# Duktape comes as one C file and no build of its own: made a shared
# library here, with the pkg-config file polkit looks for (as
# base/duktape.bst).
#
# The library's name carries the version as Duktape itself writes it
# (DUK_VERSION: 20700 for 2.7.0).  Written out here, as in the element,
# so a new version stops the build until both are changed.
if ! grep -q '^#define DUK_VERSION  *20700L' src/duktape.h; then
    echo "duktape.sh: this source is not 2.7.0, which the library's name below says" >&2
    exit 1
fi
library=libduktape.so.207.20700
gcc $CFLAGS -fPIC -shared -Wl,-soname,libduktape.so.207 \
    -o $library src/duktape.c -lm

install -D -m 755 $library $out/usr/lib/$triplet/$library
ln -s $library $out/usr/lib/$triplet/libduktape.so.207
ln -s libduktape.so.207 $out/usr/lib/$triplet/libduktape.so
install -D -m 644 -t $out/usr/include src/duktape.h src/duk_config.h
mkdir -p $out/usr/lib/$triplet/pkgconfig
printf '%s\n' 'prefix=/usr' "libdir=/usr/lib/$triplet" 'includedir=/usr/include' '' \
    'Name: duktape' 'Description: Embeddable JavaScript engine' "Version: $duktape_version" \
    'Libs: -L${libdir} -lduktape' 'Libs.private: -lm' 'Cflags: -I${includedir}' \
    > $out/usr/lib/$triplet/pkgconfig/duktape.pc
