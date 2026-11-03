kind: autotools
description: userspace-rcu -- read-copy-update library BIND uses

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: lttng:urcu/userspace-rcu-0.15.7.tar.bz2
  ref: 2556b83adc0f9b3ac8024e613e17d014d04c4c49110604ce55fcb14eae32edd3

variables:
  conf-local: --disable-static
