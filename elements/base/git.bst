kind: manual
description: |
  Git, for the devtools extension (sysext/devtools.bst).
  HTTPS through libcurl, `git grep -P` through PCRE2.  Without the parts
  written in Perl, Python and Tcl/Tk (send-email, svn, gitk, git gui), and
  without the Rust parts, which build with Cargo.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/curl.bst
- base/expat.bst
- base/openssl.bst
- base/pcre2.bst
- base/zlib.bst

sources:
- kind: tar
  url: kernel:software/scm/git/git-2.56.0.tar.xz
  ref: 26c56c296b38c0695b26fa95f475f1d01704d2d38e73465ca30b0b2f5dc789d3

variables:
  # INSTALL_SYMLINKS: the built-in commands (git-add, ...) are links to
  # git, not copies of it
  git-make: >-
    make prefix=%{prefix} gitexecdir=%{prefix}/lib/git-core sysconfdir=%{sysconfdir}
    CFLAGS="%{cflags}" USE_LIBPCRE2=1 NO_PERL=1 NO_PYTHON=1 NO_TCLTK=1
    NO_GETTEXT=1 NO_RUST=1 INSTALL_SYMLINKS=1

config:
  build-commands:
  - "%{git-make} all"
  install-commands:
  - "%{git-make} DESTDIR=%{install-root} install"
