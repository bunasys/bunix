kind: meson
description: |
  Mesa -- OpenGL and OpenGL ES through EGL and GBM, for Wayland: iris and
  crocus (Intel GPUs from 2006 on), radeonsi (AMD GCN and newer), virgl
  (virtual machines' 3D) and llvmpipe, which draws on the CPU when there
  is no supported GPU.  No GLX (no X server), no Vulkan yet, no video
  decoding.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
- base/flex.bst
- base/python-mako.bst
- base/python-pyyaml.bst
- base/python-packaging.bst
- base/wayland-protocols.bst
# the Intel drivers' OpenCL kernels are compiled while Mesa builds
# (mesa_clc): clang, SPIR-V Tools and the LLVM to SPIR-V translator
- base/llvm.bst
- base/spirv-headers.bst
- base/spirv-tools.bst
- base/spirv-llvm-translator.bst

depends:
- base/llvm-libs.bst
# radeonsi reads the shader binaries LLVM produces for AMD GPUs (ELF)
- base/elfutils.bst
- base/libdrm.bst
- base/wayland.bst
- base/expat.bst
- base/zlib.bst
- base/zstd.bst

sources:
- kind: tar
  url: https://archive.mesa3d.org/mesa-26.2.6.tar.xz
  ref: b9436b3e1a8be76fbd4823dc884f90596ab7c6ac5e1867a305e66ffccfb31a92

variables:
  meson-local: >-
    -Dplatforms=wayland -Dgallium-drivers=iris,crocus,radeonsi,virgl,llvmpipe
    -Dvulkan-drivers= -Dglx=disabled -Degl=enabled -Dgbm=enabled
    -Dopengl=true -Dgles1=disabled -Dgles2=enabled -Dglvnd=disabled
    -Dllvm=enabled -Dshared-llvm=enabled -Dgallium-va=disabled -Dvideo-codecs=
    -Dintel-rt=disabled -Dmicrosoft-clc=disabled -Dgallium-rusticl=false
    -Dvalgrind=disabled -Dlibunwind=disabled -Dlmsensors=disabled -Dselinux=false
    -Dzstd=enabled -Dexpat=enabled -Dxmlconfig=enabled -Ddisplay-info=disabled
    -Dbuild-tests=false
