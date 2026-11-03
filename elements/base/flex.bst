kind: autotools
description: flex -- the lexer generator the kernel's Kconfig and GRUB are built with

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: github:westes/flex/releases/download/v2.6.4/flex-2.6.4.tar.gz
  ref: e87aae032bf07c26f85ac0ed3250998c37621d95f8bd748b31f15b33c45ee995

variables:
  conf-local: --disable-static --disable-nls
