kind: manual
description: |
  The desktop's fonts, next to the Arabic fonts of the base
  (base/fonts-arabic.bst): Noto Sans, upright and italic, for Latin, Greek
  and Cyrillic; Noto Sans Arabic, its Arabic companion, for Arabic
  interface and web text; Noto Sans Mono (web pages' code; Ghostty has its
  own); Noto Color Emoji.  Which of them the generic names (sans-serif,
  monospace) mean is base/fontconfig.bst's rule.  From the same pinned
  commit of the Google Fonts repository, under the SIL Open Font License.

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
  url: google-fonts:2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/notosansmono/NotoSansMono%5Bwdth%2Cwght%5D.ttf
  filename: NotoSansMono[wdth,wght].ttf
  ref: 2cb2adb378a8f574213e23df697050b83c54c27df465a2015552740b2769a081
  directory: notosansmono
- kind: remote
  url: google-fonts:2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/notosans/OFL.txt
  filename: OFL.txt
  ref: cee9892f9f0cc8fe882c9e9537ee6a89621d86ee7ceaf70b02e2b2b1c25c061a
  directory: notosans

- kind: remote
  url: google-fonts:2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/notosansarabic/NotoSansArabic%5Bwdth%2Cwght%5D.ttf
  filename: NotoSansArabic[wdth,wght].ttf
  ref: 63111b5b2e074dd48cc67692e0a2726d86ee94c1c37fe8598257b7b4e87e869e
  directory: notosansarabic
- kind: remote
  url: google-fonts:2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/notosansarabic/OFL.txt
  filename: OFL.txt
  ref: 07fc70bfeb985cc1a87a8587d0a0c80bab11c86c9dc3fd95b6f0cb332f983e96
  directory: notosansarabic
- kind: remote
  url: google-fonts:2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/notocoloremoji/NotoColorEmoji-Regular.ttf
  filename: NotoColorEmoji-Regular.ttf
  ref: 4d82a18d8d95f60ba883ce242bbadbf84a576e987745dd7ba38d71c67cff2d73
  directory: notocoloremoji
- kind: remote
  url: google-fonts:2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/notocoloremoji/OFL.txt
  filename: OFL.txt
  ref: ac564676d10054a8445923dfc2dfb13c042d97888bd27c1b6ec6dfe89a9d8d62
  directory: notocoloremoji

config:
  install-commands:
  - |
    for family in notosans notosansmono notosansarabic notocoloremoji; do
      install -D -m 0644 -t %{install-root}/usr/share/fonts/$family $family/*.ttf
    done
    for family in notosans notosansarabic notocoloremoji; do
      install -D -m 0644 $family/OFL.txt %{install-root}/usr/share/licenses/fonts-$family/OFL.txt
    done
