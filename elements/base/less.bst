kind: autotools
description: less -- the pager systemctl and journalctl output goes through

build-depends:
- bootstrap/build-env.bst

depends:
- base/ncurses.bst

sources:
- kind: tar
  url: greenwood:less/less-710.tar.gz
  ref: d1008fb78dcae1323ddab664bcb352a61f022b1b131bd8018548e021d975ec7a

variables:
  # its helper programs get a directory of their own
  libexecdir: "%{prefix}/lib/less"
  # POSIX regular expressions from glibc; there is no pcre2 here
  conf-local: --with-regex=posix
