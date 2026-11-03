kind: manual
description: Ninja -- the build tool meson and CMake generate for

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: github:ninja-build/ninja/archive/v1.13.2.tar.gz
  ref: 974d6b2f4eeefa25625d34da3cb36bdcebe7fbce40f4c16ac0835fd1c0cbae17

config:
  build-commands:
  # builds ninja without an existing ninja (or CMake)
  - python3 configure.py --bootstrap
  install-commands:
  - install -D -m 0755 ninja %{install-root}%{bindir}/ninja
