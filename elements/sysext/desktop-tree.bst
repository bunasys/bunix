kind: manual
description: |
  The desktop extension's /usr: sysext/desktop-content.bst minus every
  file the base's packages ship (whether the root file system kept it or
  not), and without headers and static libraries.  It needs no other extension.  tests/desktop.bst checks it;
  sysext/desktop.bst packs it.

(@): include/release.yml

build-depends:
- bootstrap/build-env.bst
- filename: system/rootfs.bst
  config:
    location: /rootfs
- filename: base.bst
  config:
    location: /base
- filename: sysext/desktop-content.bst
  config:
    location: "%{sysroot}"

config:
  install-commands:
  # (staged dependencies are read-only: the work happens on a copy)
  - cp -a %{sysroot}/usr %{install-root}/

  - |
    # What the base's packages ship is the root file system's to keep or
    # leave out: paths it has stay its own, even where the bytes differ (it
    # strips its binaries), and what it left out stays out (systemd's getty
    # units and their .wants links, for one, would come back with the
    # merge otherwise).
    cd %{install-root}/usr
    find . ! -type d | while read -r f; do
      in_rootfs=no
      in_base=no
      if [ -e "/rootfs/usr/$f" ] || [ -L "/rootfs/usr/$f" ]; then in_rootfs=yes; fi
      if [ -e "/base/usr/$f" ] || [ -L "/base/usr/$f" ]; then in_base=yes; fi
      if [ $in_rootfs = yes ] || [ $in_base = yes ]; then
        rm -f "$f"
      fi
    done

  - |
    # What is for building software, and documentation.
    # libLLVM stays (Mesa loads it); LLVM's and clang's tools are not here
    # at all (base/llvm-libs.bst).
    cd %{install-root}/usr
    rm -rf include lib/*/pkgconfig lib/*/cmake share/pkgconfig share/aclocal \
           share/man share/info share/doc share/bash-completion share/zsh \
           share/wayland share/wayland-protocols share/vulkan
    # Qt's tools for building Qt programs (moc, qmlcachegen, ...) and what
    # they read; Qt programs need only its libraries, plugins and qml
    rm -rf lib/*/qt6/bin lib/*/qt6/libexec lib/*/qt6/mkspecs \
           lib/*/qt6/metatypes lib/*/qt6/modules lib/*/qt6/sbom
    # translations: Arabic only, as system/rootfs.bst's locales step.  GTK
    # lays its windows out right to left from its own Arabic translation.
    find share/locale -mindepth 1 -maxdepth 1 ! -name 'ar*' -exec rm -rf {} +
    rm -f bin/wayland-scanner bin/xmlwf
    find lib -maxdepth 2 \( -name '*.a' -o -name '*.la' \) -delete
    find . -type d -empty -delete

  - |
    # GSettings reads its schemas only compiled, and GTK aborts when one of
    # its own is missing (the file chooser's, for one).  Compiled here: /usr
    # is read-only on the running system.
    env LD_LIBRARY_PATH=%{sysroot}%{libdir} %{sysroot}%{bindir}/glib-compile-schemas \
      --strict %{install-root}/usr/share/glib-2.0/schemas
    ls -l %{install-root}/usr/share/glib-2.0/schemas/gschemas.compiled

  - |
    # gdk-pixbuf finds its image loaders (librsvg's SVG one: GTK's icons)
    # only through loaders.cache, which its own install step skips in a
    # staging directory.  Made from the loaders staged here, with their
    # paths as the running system sees them.
    loaders=%{libdir}/gdk-pixbuf-2.0/2.10.0
    env LD_LIBRARY_PATH=%{sysroot}%{libdir} %{sysroot}%{bindir}/gdk-pixbuf-query-loaders \
      %{sysroot}$loaders/loaders/*.so | sed 's|%{sysroot}/|/|' > %{install-root}$loaders/loaders.cache
    grep -q svg %{install-root}$loaders/loaders.cache

  - |
    # Every service in the extension must be upheld by a target: its .wants
    # links would come too late (docs/desktop.md, "Units in an extension")
    cd %{install-root}/usr/lib/systemd/system
    for service in *.service; do
      grep -q -x "Upholds=$service" *.target.d/*.conf || { echo "$service is not upheld"; exit 1; }
    done

  - |
    # Programs and shared libraries without debug information, as in the
    # root file system
    cd %{install-root}/usr
    find . -type f | while read -r f; do
      case $(file -b "$f") in
        ELF*executable*|ELF*"shared object"*) strip --strip-unneeded "$f" ;;
      esac
    done

  - |
    # sysext merges this only into the release it was built for
    # (SYSEXT_LEVEL in os-release, written by system/rootfs.bst).
    # EXTENSION_RELOAD_MANAGER: systemd reloads once this is merged, so it
    # knows the units the extension brings (docs/desktop.md, "Units in an
    # extension").
    mkdir -p %{install-root}/usr/lib/extension-release.d
    printf 'ID=bunix\nSYSEXT_LEVEL=%s\nARCHITECTURE=x86-64\nEXTENSION_RELOAD_MANAGER=1\n' \
      %{release-version} > %{install-root}/usr/lib/extension-release.d/extension-release.desktop
    du -sh %{install-root}/usr
