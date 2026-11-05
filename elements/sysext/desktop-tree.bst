kind: manual
description: |
  The desktop extension's /usr: sysext/desktop-content.bst minus every
  file the root file system already has, and without headers and static
  libraries.  It needs no other extension.  tests/desktop.bst checks it;
  sysext/desktop.bst packs it.

(@): include/release.yml

build-depends:
- bootstrap/build-env.bst
- filename: system/rootfs.bst
  config:
    location: /rootfs
- filename: sysext/desktop-content.bst
  config:
    location: "%{sysroot}"

config:
  install-commands:
  # (staged dependencies are read-only: the work happens on a copy)
  - cp -a %{sysroot}/usr %{install-root}/

  - |
    # Paths the root file system has stay the root file system's, even
    # where the bytes differ (it strips its binaries).
    cd %{install-root}/usr
    find . ! -type d | while read -r f; do
      if [ -e "/rootfs/usr/$f" ] || [ -L "/rootfs/usr/$f" ]; then
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
           share/wayland share/wayland-protocols
    # translations: Arabic only, as in the root file system.  GTK lays its
    # windows out right to left from its own Arabic translation.
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
    # (SYSEXT_LEVEL in os-release, written by system/rootfs.bst)
    mkdir -p %{install-root}/usr/lib/extension-release.d
    printf 'ID=bunix\nSYSEXT_LEVEL=%s\nARCHITECTURE=x86-64\n' %{release-version} \
      > %{install-root}/usr/lib/extension-release.d/extension-release.desktop
    du -sh %{install-root}/usr
