unpack $src
# zstd has a makefile and no configure.
# HAVE_...=0: its command also reads and writes gzip, xz and lz4 files if
#   it finds their libraries when built; each would be one more need.
zstd_make() {
    make HAVE_ZLIB=0 HAVE_LZMA=0 HAVE_LZ4=0 PREFIX=/usr LIBDIR=/usr/lib/$triplet "$@"
}
zstd_make
zstd_make DESTDIR=$out install
rm $out/usr/lib/$triplet/libzstd.a
# scripts that run grep and less, which zstd does not otherwise need
rm $out/usr/bin/{zstdgrep,zstdless} $out/usr/share/man/man1/{zstdgrep,zstdless}.1
