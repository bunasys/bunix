kind: cmake
description: |
  Qt 6 base -- Core, Gui, DBus, Network, Widgets, Test, OpenGL and the
  Wayland platform (part of qtbase since 6.10): what Quickshell, and so
  DMS, the desktop shell, are built on (desktop/quickshell.bst).

  6.12.0, the Qt that Arch builds Quickshell 0.3.2 with: Quickshell uses
  Qt's private API, so it is rebuilt for every Qt and only the pairs known
  to work are taken.  Wayland only: no X11 (xcb, Xlib); no ICU (text comes
  from HarfBuzz; Qt's own locale data covers Arabic), no SQL, no
  printing.  Vulkan only as Qt's API: Quickshell's DMA-BUF buffers use its
  types, and a Vulkan driver is loaded only if one is there (bunix has
  none).

  Laid out as Debian does, under the multiarch libdir: plugins, QML
  modules, host tools and mkspecs in /usr/lib/x86_64-linux-gnu/qt6, headers
  in /usr/include/qt6.  The other Qt modules follow this layout from
  qtbase's CMake files.

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
# Headers only, but needed by everything built on Qt too: Qt's own headers
# declare their Vulkan parts only when <vulkan/vulkan.h> is there
- desktop/vulkan-headers.bst
- base/zlib.bst
- base/zstd.bst
- base/libpng.bst
- base/libjpeg-turbo.bst
- base/openssl.bst
- base/glib.bst
- base/dbus.bst
- base/systemd.bst
- base/freetype.bst
- base/fontconfig.bst
- base/harfbuzz.bst
- base/libdrm.bst
- base/mesa.bst
- base/wayland.bst
- base/libxkbcommon.bst
- base/libinput.bst
- base/mtdev.bst

sources:
- kind: tar
  url: qt:6.12/6.12.0/submodules/qtbase-everywhere-src-6.12.0.tar.xz
  ref: a951bd163c7b80fc6b8c88d7668fb56abf91c152373e13c10666763238131307

variables:
  qt-dir: "%{lib}/qt6"
  # -DFEATURE_system_pcre2=OFF, Qt's own PCRE2: Qt needs its 16-bit library,
  # which base/pcre2.bst does not build, and building it there would rebuild
  # GLib and all above it (GTK 4, Chromium)
  cmake-local: >-
    -DQT_BUILD_EXAMPLES=OFF
    -DQT_BUILD_TESTS=OFF
    -DINSTALL_LIBDIR=%{lib}
    -DINSTALL_ARCHDATADIR=%{qt-dir}
    -DINSTALL_BINDIR=%{qt-dir}/bin
    -DINSTALL_LIBEXECDIR=%{qt-dir}/libexec
    -DINSTALL_MKSPECSDIR=%{qt-dir}/mkspecs
    -DINSTALL_INCLUDEDIR=include/qt6
    -DINSTALL_DATADIR=share/qt6
    -DINSTALL_DOCDIR=share/doc/qt6
    -DINSTALL_EXAMPLESDIR=share/doc/qt6/examples
    -DINSTALL_PUBLICBINDIR=bin
    -DFEATURE_wayland=ON
    -DFEATURE_xcb=OFF
    -DFEATURE_xlib=OFF
    -DFEATURE_icu=OFF
    -DFEATURE_sql=OFF
    -DFEATURE_printsupport=OFF
    -DFEATURE_gtk3=OFF
    -DFEATURE_openssl_linked=ON
    -DFEATURE_system_zlib=ON
    -DFEATURE_system_png=ON
    -DFEATURE_system_jpeg=ON
    -DFEATURE_system_pcre2=OFF
    -DFEATURE_system_freetype=ON
    -DFEATURE_system_harfbuzz=ON

config:
  install-commands:
    (>):
    # The Wayland platform is what makes Qt draw at all on bunix
    - ls %{install-root}%{prefix}/%{qt-dir}/plugins/platforms/libqwayland*.so
