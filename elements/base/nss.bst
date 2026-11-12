kind: manual
description: |
  NSS -- Mozilla's crypto and certificate library.  Hudhud
  (docs/browser.md) keeps its certificate databases with it (the user's
  own certificates, client certificates); its TLS is Chromium's own
  BoringSSL, and it trusts the roots it brings itself.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- base/perl.bst

depends:
- base/nspr.bst
- base/zlib.bst

sources:
- kind: tar
  url: https://ftp.mozilla.org/pub/security/nss/releases/NSS_3_133_RTM/src/nss-3.133.tar.gz
  ref: 4d752526b9846a1d962588cfbd09b7cc2a4f6a4effbd9157d58a30e8a2573065

config:
  # NSS has its own make files (coreconf), no configure step.  Optimized,
  # 64-bit, the system's NSPR and zlib; its bundled SQLite (for the
  # certificate databases).  No tests: they are most of the build.
  build-commands:
  - |
    cd nss
    make BUILD_OPT=1 USE_64=1 NSS_ENABLE_WERROR=0 NSS_DISABLE_GTESTS=1 \
      NSPR_INCLUDE_DIR=%{includedir}/nspr NSPR_LIB_DIR=%{libdir} \
      USE_SYSTEM_ZLIB=1 ZLIB_LIBS=-lz \
      -j1

  install-commands:
  - |
    cd dist
    mkdir -p %{install-root}%{libdir}/pkgconfig %{install-root}%{includedir}/nss %{install-root}%{bindir}
    cp Linux*/lib/*.so Linux*/lib/*.chk %{install-root}%{libdir}/
    cp -RL public/nss/* private/nss/* %{install-root}%{includedir}/nss/
    # certutil and pk12util: managing the certificate databases by hand
    cp Linux*/bin/certutil Linux*/bin/pk12util %{install-root}%{bindir}/

  - |
    # NSS's own nss.pc assumes lib/, not the multiarch $libdir
    version=$(sed -n 's/^#define NSS_VERSION "\([0-9.]*\).*/\1/p' nss/lib/nss/nss.h)
    cat > %{install-root}%{libdir}/pkgconfig/nss.pc <<PC
    prefix=%{prefix}
    libdir=%{libdir}
    includedir=%{includedir}/nss

    Name: NSS
    Description: Network Security Services
    Version: $version
    Requires: nspr
    Libs: -L\${libdir} -lnss3 -lnssutil3 -lsmime3 -lssl3
    Cflags: -I\${includedir}
    PC
    cat %{install-root}%{libdir}/pkgconfig/nss.pc
