kind: meson
description: |
  Graphene -- vectors, matrices and rectangles for GTK's scene graph, with
  their GObject types

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/glib.bst

sources:
- kind: tar
  url: gnome:graphene/1.10/graphene-1.10.8.tar.xz
  ref: a37bb0e78a419dcbeaa9c7027bcff52f5ec2367c25ec859da31dfde2928f279a

variables:
  meson-local: >-
    -Dgobject_types=true -Dintrospection=disabled -Dtests=false -Dinstalled_tests=false
