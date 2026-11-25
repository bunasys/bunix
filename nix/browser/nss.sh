unpack $src
# NSS has its own make files (coreconf), and no configure step.
# Optimized, 64-bit, the system's NSPR and zlib, its own SQLite (for the
# certificate databases).  No tests: they are most of the build.  -j1:
# coreconf's make files do not hold together in parallel.
libdir=/usr/lib/$triplet
cd nss
make BUILD_OPT=1 USE_64=1 NSS_ENABLE_WERROR=0 NSS_DISABLE_GTESTS=1 \
    NSPR_INCLUDE_DIR=/usr/include/nspr NSPR_LIB_DIR=$libdir \
    USE_SYSTEM_ZLIB=1 ZLIB_LIBS=-lz -j1
cd ../dist

mkdir -p $out$libdir/pkgconfig $out/usr/include/nss $out/usr/bin
# The libraries and the modules NSS loads by name when it runs (softokn,
# freebl, nssckbi's built-in roots), with their .chk signatures, which
# the FIPS self-test checks them against.  The signatures are made before
# system-package.sh strips the libraries, so on a machine in FIPS mode
# (fips_enabled=1) the self-test fails; bunix does not run in it.
# libsqlite3.so is NSS's own SQLite, which softokn needs: nothing else of
# bunix links SQLite.
cp Linux*/lib/*.so Linux*/lib/*.chk $out$libdir/
# a module for NSS's own tests
rm $out$libdir/libnssckbi-testlib.so
# What NSS installs for others to build against is both directories'
# headers: "private" ones that public ones include
cp -RL public/nss/* private/nss/* $out/usr/include/nss/
# certutil and pk12util: a person's certificate databases, by hand
cp Linux*/bin/certutil Linux*/bin/pk12util $out/usr/bin/

# NSS installs no nss.pc of its own that has UAPI.9's directories
version=$(sed -n 's/^#define NSS_VERSION "\([0-9.]*\).*/\1/p' ../nss/lib/nss/nss.h)
[ -n "$version" ]
cat > $out$libdir/pkgconfig/nss.pc <<PC
prefix=/usr
libdir=$libdir
includedir=/usr/include/nss

Name: NSS
Description: Network Security Services
Version: $version
Requires: nspr
Libs: -L\${libdir} -lnss3 -lnssutil3 -lsmime3 -lssl3
Cflags: -I\${includedir}
PC
