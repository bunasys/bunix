kind: manual
description: |
  The IANA time zone database -- /usr/share/zoneinfo, which glibc reads
  for local time and timedatectl lists and links /etc/localtime into --
  and its compiler zic, and zdump

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: https://data.iana.org/time-zones/releases/tzcode2026f.tar.gz
  ref: 5a18da01393679ef2559214dc687563f7f3d05691f6f58b7fbc0166f3e796cd6
  base-dir: ''
- kind: tar
  url: https://data.iana.org/time-zones/releases/tzdata2026f.tar.gz
  ref: 01b4a91cec5167ed48c11e8ab78f2048cead78ce94b0cafcad0ae8c5a3044d3d
  base-dir: ''

variables:
  # "slim" zone files: glibc computes future transitions from the TZ rule
  # each file ends with, so the files do not list them (a third the size).
  # posix_only: no right/ copy of every zone with leap seconds counted.
  tz-make: >-
    make CC=gcc CFLAGS="%{cflags}" ZFLAGS="-b slim" REDO=posix_only USRDIR=usr ZICDIR=/usr/bin

config:
  build-commands:
  - "%{tz-make}"
  install-commands:
  - "%{tz-make} DESTDIR=%{install-root} install"
  # /etc belongs to the system's owner: timedatectl creates /etc/localtime.
  # The static library and man pages are for building software.
  - rm -rf %{install-root}/etc %{install-root}/usr/lib %{install-root}/usr/share/man
