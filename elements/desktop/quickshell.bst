kind: cmake
description: |
  Quickshell -- a toolkit for desktop shells written in QML: panels,
  launchers, lock screens as Wayland layer-shell windows, with services
  for PipeWire, MPRIS, the system tray, notifications, PAM, polkit,
  greetd, UPower, Bluetooth and the network.  DMS (desktop/dms.bst) and its
  login screen (desktop/dms-greeter.bst) are QML run by its `qs`.

  It uses Qt's private API, so it is built for one Qt release
  (desktop/qt6-base.bst says which).  No X11 and no crash handler (it needs
  cpptrace, and writes reports for upstream).  Its QML modules go beside
  Qt's own, in /usr/lib/x86_64-linux-gnu/qt6/qml.

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst
- desktop/qt6-shadertools.bst
- desktop/cli11.bst
- desktop/vulkan-headers.bst
- base/wayland-protocols.bst

depends:
- desktop/qt6-base.bst
- desktop/qt6-declarative.bst
- desktop/qt6-svg.bst
- desktop/jemalloc.bst
- base/wayland.bst
- base/libdrm.bst
- base/mesa.bst
- base/pipewire.bst
- base/linux-pam.bst
- base/polkit.bst
- base/glib.bst

sources:
- kind: tar
  url: github:quickshell-mirror/quickshell/archive/refs/tags/v0.3.2.tar.gz
  ref: 946a27e2a276917a03c1079e5c60971af84ece73088c3661dee455d92eb420f7

variables:
  cmake-local: >-
    -DDISTRIBUTOR=bunix
    -DGIT_REVISION=8e2bb761d3e994fc04359c55dec269b747654b6a
    -DCRASH_HANDLER=OFF
    -DX11=OFF
    -DINSTALL_QML_PREFIX=%{lib}/qt6/qml

config:
  install-commands:
    (>):
    - test -f %{install-root}%{prefix}/%{lib}/qt6/qml/Quickshell/qmldir
