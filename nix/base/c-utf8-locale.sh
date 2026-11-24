# Where glibc looks for a compiled locale: under its own library
# directory (toolchain/glibc.sh, --libdir), not /usr/lib/locale.
# --no-archive: a directory of its own, C.utf8 (the name as glibc writes
# a codeset), and not the archive of every locale, which a machine's own
# localedef would write over.
locales=$out/usr/lib/$triplet/locale
mkdir -p $locales
localedef --no-archive -i C -f UTF-8 $locales/C.utf8
