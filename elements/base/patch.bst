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
  url: gnu:patch/patch-2.8.tar.xz
  ref: f87cee69eec2b4fcbf60a396b030ad6aa3415f192aa5f7ee84cad5e11f7f5ae3

variables:
  conf-local: --disable-nls
