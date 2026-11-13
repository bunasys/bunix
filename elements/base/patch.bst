kind: autotools
description: |
  GNU patch -- applies diffs.  For building Hudhud (base/chromium.bst):
  ungoogled-chromium's patches and Hudhud's are applied while the source is
  prepared (files/hudhud/scripts/prepare-source.sh), in the build sandbox,
  where BuildStream's own patch sources do not reach.

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: gnu:patch/patch-2.8.1.tar.xz
  ref: 3240c7959c5347c8ed347e3c4201c0337bf4240d5cf09d68889e58eeaba30e17

variables:
  conf-local: --disable-nls
