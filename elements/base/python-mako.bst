kind: manual
description: |
  Mako -- the template engine Mesa's build generates code with

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

depends:
- base/python-markupsafe.bst

sources:
- kind: pypi
  url: "pypi:"
  name: mako
  ref:
    sha256sum: cd6537fe88d5fec315c55c2f8529bc4ce7a9a352ad7db3eeaa6a66e2dd4ec37a
    suffix: 5a/09/e07c4b5579a79f4b16f8d4f29f6c54514ac787c4ad506b8c4f28a0e6b0bf/mako-1.4.3.tar.gz
config:
  install-commands:
  # pure Python: installing it is copying it, as for meson
  - |
    site=%{install-root}$(python3 -c 'import sysconfig; print(sysconfig.get_path("purelib"))')
    mkdir -p "$site"
    cp -r mako "$site/"
