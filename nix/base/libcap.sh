unpack $src
# libcap has a makefile and no configure.  The element's arguments: no Go
# bindings, no PAM module; RAISE_SETFCAP would give the installed setcap a
# capability, which a build cannot.
libcap_make() {
    make prefix=/usr lib=lib/$triplet SBINDIR=/usr/bin GOLANG=no PAM_CAP=no RAISE_SETFCAP=no "$@"
}
libcap_make
libcap_make DESTDIR=$out install
rm $out/usr/lib/$triplet/libcap.a $out/usr/lib/$triplet/libpsx.a
