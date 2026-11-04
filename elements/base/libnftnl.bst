kind: autotools
description: libnftnl -- the kernel's nftables netlink interface, for nft

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/libmnl.bst

sources:
- kind: tar
  url: netfilter:libnftnl/files/libnftnl-1.3.2.tar.xz
  ref: c97abc3409f8fa396b4462b2bb7f147a3a47a4ddc97cfa0b2f18890c9cfde8b0

variables:
  conf-local: --disable-static
