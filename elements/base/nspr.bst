kind: autotools
description: |
  NSPR -- the Netscape Portable Runtime, the platform layer NSS is
  written on (base/nss.bst).  For Hudhud (docs/browser.md).

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: https://ftp.mozilla.org/pub/nspr/releases/v4.40/src/nspr-4.40.tar.gz
  ref: c0c1884c627f3db7a783f7c7314c695226b2043696791d15519e7e0578c19bdc

variables:
  # the tarball's top directory holds only nspr/
  command-subdir: nspr
  conf-local: --enable-64bit --with-pthreads --enable-optimize --disable-debug

config:
  install-commands:
    (>):
    # static libraries, and NSPR's error-table tools, which nothing here
    # uses
    - rm -f %{install-root}%{libdir}/*.a %{install-root}%{bindir}/compile-et.pl %{install-root}%{bindir}/prerr.properties
