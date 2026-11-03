kind: manual
description: Meson -- the build system systemd and dbus use

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

depends:
- base/python.bst

sources:
- kind: tar
  url: github:mesonbuild/meson/releases/download/1.12.1/meson-1.12.1.tar.gz
  ref: ab0a6ca09f8ef70c564c8241fb5a23957886a0b53fb58412b5e07eaf07dba743

config:
  install-commands:
  # Meson is pure Python, so installing it is copying it -- no need to build
  # Python's packaging tools (setuptools, pip) first.  The script is the
  # entry point its own packaging would generate.
  - |
    site=%{install-root}$(python3 -c 'import sysconfig; print(sysconfig.get_path("purelib"))')
    mkdir -p "$site" %{install-root}%{bindir}
    cp -r mesonbuild "$site/"
    printf '#!/usr/bin/python3\nimport sys\nfrom mesonbuild.mesonmain import main\nsys.exit(main())\n' \
      > %{install-root}%{bindir}/meson
    chmod 0755 %{install-root}%{bindir}/meson
