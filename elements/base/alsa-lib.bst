kind: autotools
description: |
  alsa-lib -- the library programs play and record sound with, straight
  to the kernel's sound drivers or through PipeWire (its ALSA plugin,
  base/pipewire.bst), and its configuration in /usr/share/alsa, which
  every copy of libasound reads

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: https://www.alsa-project.org/files/pub/lib/alsa-lib-1.2.16.1.tar.bz2
  ref: f740db7f488255944ffd4428416ee3390a96742856916433df468c281436480e

variables:
  conf-local: --disable-static --without-debug --disable-python --disable-topology

config:
  install-commands:
    (>):
    # alsa.conf reads drop-ins from /etc/alsa/conf.d, which an extension
    # cannot carry; also from /usr/share/alsa/alsa.conf.d, where PipeWire
    # puts the file that makes it ALSA's default device (base/pipewire.bst).
    # First in the list, so /etc's files still win.
    - |
      conf=%{install-root}/usr/share/alsa/alsa.conf
      sed -i 's|^\t\t\t"/var/lib/alsa/conf.d"$|\t\t\t"/usr/share/alsa/alsa.conf.d"\n\t\t\t"/var/lib/alsa/conf.d"|' $conf
      grep -q '"/usr/share/alsa/alsa.conf.d"' $conf
