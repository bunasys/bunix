kind: cmake
description: |
  Qt 6 Declarative -- QML and Qt Quick (with Layouts, Shapes, Effects,
  Controls and Qt.labs.folderlistmodel): the language and scene graph
  DMS's whole UI is written in, through Quickshell.

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst
- desktop/qt6-shadertools.bst

depends:
- desktop/qt6-base.bst
- desktop/qt6-svg.bst

sources:
- kind: tar
  url: qt:6.12/6.12.0/submodules/qtdeclarative-everywhere-src-6.12.0.tar.xz
  ref: 311f3a2603e1973bb59baef9dfa740a376de713157d4782ee043681e889c9260

variables:
  cmake-local: -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF

config:
  install-commands:
    (>):
    - test -f %{install-root}%{prefix}/%{lib}/qt6/qml/QtQuick/Effects/qmldir
