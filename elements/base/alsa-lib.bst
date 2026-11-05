kind: autotools
description: |
  alsa-lib -- the library programs play and record sound with, straight
  to the kernel's sound drivers (and, from phase 4, through PipeWire), and
  its configuration in /usr/share/alsa, which every copy of libasound reads
  -- Chromium's own included

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: https://www.alsa-project.org/files/pub/lib/alsa-lib-1.2.16.1.tar.bz2
  ref: f740db7f488255944ffd4428416ee3390a96742856916433df468c281436480e

variables:
  conf-local: --disable-static --without-debug --disable-python --disable-topology
