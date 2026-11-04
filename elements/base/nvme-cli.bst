kind: meson
description: |
  nvme-cli -- talks to NVMe drives: health (smart-log), firmware, error
  log, namespaces.  Only for local drives: no NVMe over Fabrics, no
  management interface, no Python bindings.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/json-c.bst

sources:
- kind: tar
  url: github:linux-nvme/nvme-cli/archive/refs/tags/v3.2.tar.gz
  ref: 8ad36c9fe68a01e73e0dd542afdc38cc51309ed185fa9b80e4b0a8c61831a235

variables:
  meson-local: >-
    -Dversion-tag=3.2 -Djson-c=enabled
    -Dfabrics=disabled -Dmi=disabled -Dnvme-discoverd=disabled -Dmdns=disabled
    -Dkmip=disabled -Dnvmf-autoconnect=disabled -Dtop=disabled -Dpython=disabled
    -Dopenssl=disabled -Dkeyutils=disabled -Dlibarchive=disabled -Dlibkmod=disabled
    -Ddocs=false -Dtests=false -Dexamples=false
