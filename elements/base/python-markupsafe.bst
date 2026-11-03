kind: manual
description: MarkupSafe -- string escaping for Jinja2

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

depends:
- base/python.bst

sources:
- kind: pypi
  url: "pypi:"
  name: markupsafe
  ref:
    sha256sum: 2e9ad7dd851bf45fab9f75cbff4cb493fee9979e8d8c7c9c3ee119022518edd6
    suffix: 38/9b/e422a865e1d5d57d0e509b4e0bf1c1a70a7f6382c29a5aa428df994c8bc8/markupsafe-3.0.4.tar.gz
config:
  install-commands:
  # Pure Python (it falls back from its optional C speedups), so installing
  # it is copying it, as for meson.
  - |
    site=%{install-root}$(python3 -c 'import sysconfig; print(sysconfig.get_path("purelib"))')
    mkdir -p "$site"
    cp -r src/markupsafe "$site/"
    rm -f "$site"/markupsafe/*.c
