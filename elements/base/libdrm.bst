kind: meson
description: |
  libdrm -- the kernel's graphics interface (DRM/KMS) from user space: what
  Plymouth draws the boot splash through, and later Mesa and the compositor.
  The GPU-specific libraries Mesa uses (amdgpu, radeon, nouveau) are built
  now so that adding Mesa does not change this element; intel's needs
  libpciaccess, and Mesa's Intel drivers do not use it.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

sources:
- kind: tar
  url: freedesktop-dri:libdrm/libdrm-2.4.134.tar.xz
  ref: ac5e74d157830eb8bee44c6a6bf3ad49774ef0dd2a72bdad74a8f20308b52a95

variables:
  meson-local: >-
    -Damdgpu=enabled -Dradeon=enabled -Dnouveau=enabled -Dvmwgfx=enabled
    -Dintel=disabled -Domap=disabled -Dexynos=disabled -Dfreedreno=disabled
    -Dtegra=disabled -Dvc4=disabled -Detnaviv=disabled
    -Dcairo-tests=disabled -Dman-pages=disabled -Dvalgrind=disabled
    -Dtests=false -Dudev=true
