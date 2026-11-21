# Only the libraries, libelf and libdw, not elfutils' programs: the
# top-level makefile would build those too, so each part is built and
# installed by its own.
unpack $src
# --without-...: each compression it finds would be one more library the
#   package needs; zlib it cannot do without.
./configure $configure_for_usr --disable-nls \
    --disable-debuginfod --enable-libdebuginfod=dummy \
    --without-bzlib --without-lzma --without-zstd
make -C lib
make -C libelf
# libdw is linked from these parts' static archives
for part in libcpu backends libebl libdwelf libdwfl libdwfl_stacktrace libdw; do
    make -C $part
done

make -C libelf DESTDIR=$out install
install -D -m 644 config/libelf.pc $out/usr/lib/$triplet/pkgconfig/libelf.pc
for part in libdw libdwfl libdwelf; do
    make -C $part DESTDIR=$out install
done
# (the top-level makefile installs this one)
install -m 644 version.h $out/usr/include/elfutils/version.h
install -m 644 config/libdw.pc $out/usr/lib/$triplet/pkgconfig/libdw.pc
rm $out/usr/lib/$triplet/libelf.a $out/usr/lib/$triplet/libdw.a
