kind: meson
description: |
  usbutils -- lsusb.  Devices are shown by the names they report
  themselves: names from the ID list come through udev's hwdb, which
  systemd here is built without.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/libusb.bst
- base/systemd.bst

sources:
- kind: tar
  url: kernel:linux/utils/usb/usbutils/usbutils-020.tar.xz
  ref: 20287d68fcd9ebb50a05ba0645a4af7583bd8dfc7307215ba121e4bc6d057aa1

config:
  # usb-devices and lsusb.py are shell and Python scripts around lsusb
  install-commands:
    (>):
    - rm -f %{install-root}%{bindir}/usb-devices %{install-root}%{bindir}/lsusb.py
