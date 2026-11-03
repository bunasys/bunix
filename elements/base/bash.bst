kind: autotools
description: GNU bash -- /bin/sh and /bin/bash (fish is the login shell)

build-depends:
- bootstrap/build-env.bst

depends:
- base/ncurses.bst

sources:
- kind: tar
  url: gnu:bash/bash-5.3.tar.gz
  ref: 0d5cd86965f869a26cf64f4b71be7b96f90a3ba8b3d74e27e8e9d9d5550f31ba

variables:
  # bash's own malloc is for systems with a poor libc allocator; glibc's is
  # fine.  readline is the copy bundled with bash.
  conf-local: --without-bash-malloc --with-installed-readline=no --disable-nls

config:
  install-commands:
    (>):
    - ln -s bash %{install-root}%{bindir}/sh

public:
  bst:
    # replaces the bootstrap's temporary bash in build sandboxes
    overlap-whitelist:
    - "**"
