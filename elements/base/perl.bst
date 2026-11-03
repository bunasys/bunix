kind: manual
description: Perl 5 -- needed to build OpenSSL (its Configure is a Perl program)

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: cpan:perl-5.44.0.tar.xz
  ref: 505cf43912e9480495c344c70260452e32aa2a73c546a026b3f100053b23ce91

config:
  configure-commands:
  # Arch Linux's layout: core modules in core_perl, distribution-packaged
  # modules in vendor_perl; architecture-independent ones under /usr/share
  - |
    sh Configure -des -Dcc=gcc \
      -Dprefix=/usr -Dvendorprefix=/usr \
      -Dprivlib=/usr/share/perl5/core_perl -Darchlib=/usr/lib/perl5/core_perl \
      -Dvendorlib=/usr/share/perl5/vendor_perl -Dvendorarch=/usr/lib/perl5/vendor_perl \
      -Dsitelib=/usr/share/perl5/site_perl -Dsitearch=/usr/lib/perl5/site_perl \
      -Dscriptdir=/usr/bin -Dsitescript=/usr/bin -Dvendorscript=/usr/bin \
      -Dman1dir=/usr/share/man/man1 -Dman3dir=/usr/share/man/man3 \
      -Dinc_version_list=none -Duseshrplib -Dusethreads \
      -Doptimize="%{cflags}" -Dldflags="%{ldflags}" -Dlddlflags="-shared %{ldflags}"
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root} install
