kind: manual
description: The Linux kernel's userspace API headers, into the sysroot (bootstrap stage 1)

build-depends:
- bootstrap/seed.bst

sources:
- kind: tar
  url: kernel:linux/kernel/v6.x/linux-6.18.52.tar.xz
  ref: 2b69564f7d4fea0c859b1959ba33709ee6e9139bd100e30a853b57159a8221b8

config:
  build-commands:
  - make ARCH=x86_64 headers
  - find usr/include -type f ! -name '*.h' -delete
  install-commands:
  - mkdir -p %{install-root}%{sysroot}/usr
  - cp -r usr/include %{install-root}%{sysroot}/usr/
