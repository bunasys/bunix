kind: autotools
description: |
  libcanberra -- event sounds (Hyprland links it).  With the null backend
  only for now: no ALSA, PulseAudio or GStreamer output.

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst
- base/libtool.bst

depends:
- base/libvorbis.bst
- base/libtool.bst

sources:
- kind: tar
  url: http://0pointer.de/lennart/projects/libcanberra/libcanberra-0.30.tar.xz
  ref: c2b671e67e0c288a69fc33dc1b6f1b534d07882c2aceed37004bf48c601afa72

variables:
  conf-local: >-
    --disable-static --disable-alsa --disable-oss --disable-pulse --disable-gstreamer
    --disable-gtk --disable-gtk3 --disable-tdb --disable-udev --disable-lynx --enable-null

environment:
  # 2012 code: C23, gcc 16's default, rejects its old-style declarations
  CFLAGS: "%{cflags} -std=gnu17"
