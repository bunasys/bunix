kind: manual
description: |
  desktop_<release>.raw: the graphical system (sysext/desktop-tree.bst) as a system extension image, made by
  include/sysext-image.yml.

(@):
- include/release.yml
- include/sysext-image.yml

build-depends:
- bootstrap/build-env.bst
# systemd-repart builds the image; mkfs.erofs and libcryptsetup do the work
- base/systemd.bst
- base/erofs-utils.bst
- filename: sysext/desktop-tree.bst
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
  extension: desktop
  seed: 7cc97b26-efe9-4486-96b2-9de25c116f77
