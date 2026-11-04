kind: manual
description: |
  devtools_<release>.raw: git, gdb, strace and the rest (sysext/devtools-tree.bst) as a system extension image, made by
  include/sysext-image.yml.

(@):
- include/release.yml
- include/sysext-image.yml

build-depends:
- bootstrap/build-env.bst
# systemd-repart builds the image; mkfs.erofs and libcryptsetup do the work
- base/systemd.bst
- base/erofs-utils.bst
- filename: sysext/devtools-tree.bst
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
  extension: devtools
  seed: 7a58e871-9c99-464b-9668-472a3c6e3ea6
