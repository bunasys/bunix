kind: manual
description: |
  rust_<release>.raw: Rust (sysext/rust-tree.bst) as a system extension image, made by
  include/sysext-image.yml.

(@):
- include/release.yml
- include/sysext-image.yml

build-depends:
- bootstrap/build-env.bst
# systemd-repart builds the image; mkfs.erofs and libcryptsetup do the work
- base/systemd.bst
- base/erofs-utils.bst
- filename: sysext/rust-tree.bst
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
  extension: rust
  seed: 3b9d6e2f-7c41-4a85-b0d2-5e8f1a6c9d47
