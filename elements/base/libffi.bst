kind: autotools
description: libffi -- calls into C from Python's ctypes, which systemd-boot's build (elf2efi) uses

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: github:libffi/libffi/releases/download/v3.8.0/libffi-3.8.0.tar.gz
  ref: 7da3e2d9a171eb0a038f592ecad3ff2bb2550f3496d87b3b29ad0cf4430c0db4

variables:
  # --disable-multi-os-directory: otherwise libffi appends gcc's multilib
  # directory (../lib/x86_64-linux-gnu) to --libdir, as libstdc++ does
  conf-local: --disable-static --disable-docs --disable-multi-os-directory
