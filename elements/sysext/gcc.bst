kind: manual
description: |
  gcc_<release>.raw: the C/C++ toolchain (sysext/gcc-tree.bst) as a system extension image, made by
  include/sysext-image.yml.

(@):
- include/release.yml
- include/sysext-image.yml

build-depends:
- bootstrap/build-env.bst
# systemd-repart builds the image; mkfs.erofs and libcryptsetup do the work
- base/systemd.bst
- base/erofs-utils.bst
- filename: sysext/gcc-tree.bst
  config:
    location: /extension

sources:
- kind: local
  path: files/sysext/repart.d
  directory: repart.d
# Only the image signing key (kept out of version control), not keys/'s
# other keys.
- kind: local
  path: keys/verity.key
  directory: keys
- kind: local
  path: keys/verity.crt
  directory: keys

variables:
  extension: gcc
  seed: f2c5d5a8-2b9e-4a63-9a43-6a3b8f1e0d7c
