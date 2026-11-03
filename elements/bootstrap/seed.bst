kind: import
description: |
  The binary seed the bootstrap starts from: Arch Linux's base-devel image
  (gcc, binutils, make, bash, coreutils, perl, python...).  Only bootstrap
  stages 1 and 2 build inside it; nothing from it reaches the final system.

sources:
- kind: docker
  image: library/archlinux
  track: base-devel
  architecture: amd64
  ref: cb06b309ab9424b354a8e1099a934fc48b13e62c3d4453d19d50beaa72c6caee
