kind: autotools
description: |
  acl -- POSIX access control lists, and getfacl/setfacl.  systemd loads
  libacl when it needs it: logind gives the user at the seat their sound,
  cameras, security keys and game controllers (the uaccess udev rules) and
  takes them back when they leave; systemd-tmpfiles lets administrators
  read the journal.  In the base, not the desktop extension: without it
  udev logs an error for each such device at every boot, and devices
  plugged in during a session would get no access.

build-depends:
- bootstrap/build-env.bst

depends:
- base/attr.bst

sources:
- kind: tar
  url: https://download.savannah.nongnu.org/releases/acl/acl-2.4.0.tar.xz
  ref: e661131456d2708a01c614a0f400e11d7d1bfaeb6f3e74b75bb980b72f0161a3

variables:
  conf-local: --disable-static --disable-nls
