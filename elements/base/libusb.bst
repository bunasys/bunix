kind: autotools
description: libusb -- user-space access to USB devices (lsusb)

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/systemd.bst

sources:
- kind: tar
  url: github:libusb/libusb/releases/download/v1.0.30/libusb-1.0.30.tar.bz2
  ref: fea36f34f9156400209595e300840767ab1a385ede1dc7ee893015aea9c6dbaf

variables:
  conf-local: --disable-static --enable-udev --disable-examples-build --disable-tests-build
