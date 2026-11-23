unpack $src
# A snapshot of the repository, which has no configure: autoreconf makes
# it.  The element's arguments: LZ4 (fast to read: a system's /usr, and
# here its extensions too) and LZMA (small: what x86 made extensions
# with); FUSE mounting, importing from S3
# and registries, and SELinux labels are off.
autoreconf -fi
./configure $configure_for_usr \
    --enable-lz4 --enable-lzma --without-libzstd --disable-fuse \
    --without-selinux --without-libcurl --without-openssl --without-libxml2 \
    --without-json_c --without-libnl3
make
make DESTDIR=$out install
