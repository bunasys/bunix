kind: manual
description: |
  Noto Sans, upright and italic, variable in weight and width: the
  desktop's interface font for Latin, Greek and Cyrillic, next to the
  Arabic fonts (base/fonts-arabic.bst).  From the same pinned commit of the
  Google Fonts repository, under the SIL Open Font License.

build-depends:
- bootstrap/build-env.bst

sources:
- kind: remote
  url: google-fonts:2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/notosans/NotoSans%5Bwdth%2Cwght%5D.ttf
  filename: NotoSans[wdth,wght].ttf
  ref: bfb7bb691513f12e734dc346c03a03f784912432d7e3fa8e56efcf906fe86b3d
  directory: notosans
- kind: remote
  url: google-fonts:2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/notosans/NotoSans-Italic%5Bwdth%2Cwght%5D.ttf
  filename: NotoSans-Italic[wdth,wght].ttf
  ref: 58e6e0ebd1931b29a365aa2d3e2ee9a9e831a3af7cf3ad1462d4e72154f0b291
  directory: notosans
- kind: remote
  url: google-fonts:2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/notosans/OFL.txt
  filename: OFL.txt
  ref: cee9892f9f0cc8fe882c9e9537ee6a89621d86ee7ceaf70b02e2b2b1c25c061a
  directory: notosans

config:
  install-commands:
  - |
    install -D -m 0644 -t %{install-root}/usr/share/fonts/notosans notosans/*.ttf
    install -D -m 0644 notosans/OFL.txt %{install-root}/usr/share/licenses/fonts-notosans/OFL.txt
