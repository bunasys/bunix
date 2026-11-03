kind: manual
description: |
  swift_<release>.raw: Swift (sysext/swift-tree.bst) as a system extension image, made by
  include/sysext-image.yml.

(@):
- include/release.yml
- include/sysext-image.yml

build-depends:
- bootstrap/build-env.bst
# systemd-repart builds the image; mkfs.erofs and libcryptsetup do the work
- base/systemd.bst
- base/erofs-utils.bst
- filename: sysext/swift-tree.bst
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
  extension: swift
  seed: 8e4a1c7d-2f69-4b3e-a5d0-9c6b2e8f7a14
