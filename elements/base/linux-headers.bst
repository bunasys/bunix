kind: manual
description: |
  The kernel's user-space API headers (/usr/include/linux, asm, ...), for
  compiling programs on bunix -- from the same kernel as system/linux.bst

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: kernel:linux/kernel/v6.x/linux-6.18.63.tar.xz
  ref: 81764a545072d160748beff4d9de2e7d95aa9f16e8261110288f067a2cc61d71

config:
  # `make headers_install` copies with rsync, which bunix lacks: the headers
  # are generated in usr/include and copied from there instead
  build-commands:
  - make headers
  - find usr/include -type f ! -name '*.h' -delete
  install-commands:
  - mkdir -p %{install-root}/usr
  - cp -r usr/include %{install-root}/usr/
