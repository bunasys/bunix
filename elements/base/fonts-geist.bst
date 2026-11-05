kind: manual
description: |
  Geist and Geist Mono, variable in weight: the Banan Design System's Latin
  faces, which bunix's own screens use (base/buna-login.bst), with IBM Plex
  Sans Arabic for Arabic (base/fonts-arabic.bst).  From the same pinned
  commit of the Google Fonts repository as the other fonts, under the SIL
  Open Font License.

build-depends:
- bootstrap/build-env.bst

sources:
- kind: remote
  url: google-fonts:2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/geist/Geist%5Bwght%5D.ttf
  filename: Geist[wght].ttf
  ref: 73894e0448cae90a92b6c2f8732b7bb9acb7b94c418bff559dad4a18e1de9659
  directory: geist
- kind: remote
  url: google-fonts:2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/geist/OFL.txt
  filename: OFL.txt
  ref: 1781d2806a07d91c4edf4740b88449fab7d0eadad53f7c351b94cd4d4eb8c00f
  directory: geist
- kind: remote
  url: google-fonts:2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/geistmono/GeistMono%5Bwght%5D.ttf
  filename: GeistMono[wght].ttf
  ref: d00e590b8eb3a59acc329b2d044fd143ae935090b7da33199ebee27cc7de8196
  directory: geistmono

config:
  install-commands:
  - |
    for family in geist geistmono; do
      install -D -m 0644 -t %{install-root}/usr/share/fonts/$family $family/*.ttf
    done
    install -D -m 0644 geist/OFL.txt %{install-root}/usr/share/licenses/fonts-geist/OFL.txt
