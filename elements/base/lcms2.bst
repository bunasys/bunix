kind: autotools
description: |
  Little CMS -- colour management: ICC profiles (Hyprland's colour pipeline)

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: github:mm2/Little-CMS/releases/download/lcms2.20/lcms2-2.20.tar.gz
  ref: 18ff5504fa9cc8a2b1f3591180d90ead16c8a2ea78e530523b46eab70e1ca6b9

variables:
  conf-local: --disable-static
