kind: manual
description: |
  The kernel's user-space API headers (/usr/include/linux, asm, ...), for
  compiling programs on bunix -- from the same kernel as system/linux.bst

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: kernel:linux/kernel/v6.x/linux-6.18.60.tar.xz
  ref: 3c2f44ef6acc021a7ad444d9a2e6ec1ef488ff09368793d0004a6080f69d621e

config:
  # `make headers_install` copies with rsync, which bunix lacks: the headers
  # are generated in usr/include and copied from there instead
  build-commands:
  - make headers
  - find usr/include -type f ! -name '*.h' -delete
  install-commands:
  - mkdir -p %{install-root}/usr
  - cp -r usr/include %{install-root}/usr/
