kind: autotools
description: pkgconf -- pkg-config, which build systems ask where libraries are

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: pkgconf:pkgconf-3.0.10.tar.xz
  ref: 9371b2f6372da574d4c6dc96fe9b1463037bcf6afcb6671c1555afde7b17e2de

variables:
  # .pc files live in the multiarch $libdir; a few packages still put them
  # in /usr/lib or /usr/share
  conf-local: >-
    --disable-static
    --with-pkg-config-dir=%{libdir}/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig
    --with-system-libdir=%{libdir}:/usr/lib
    --with-system-includedir=/usr/include

config:
  install-commands:
    (>):
    - ln -s pkgconf %{install-root}%{bindir}/pkg-config
