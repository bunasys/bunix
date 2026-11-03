kind: autotools
description: |
  xz -- liblzma, which systemd's image downloader (systemd-pull) needs, and
  the xz tool

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: github:tukaani-project/xz/releases/download/v5.8.4/xz-5.8.4.tar.xz
  ref: 4ce24038fd4221e0d13bc1a2de7a4db56e90b92b3bf75321f6c14be73f65de4b

variables:
  conf-local: --disable-static --disable-nls --disable-doc
