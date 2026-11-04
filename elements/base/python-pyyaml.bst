kind: manual
description: |
  PyYAML -- Mesa's build reads its driver tables with it (pure Python,
  without libyaml)

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

sources:
- kind: pypi
  url: "pypi:"
  name: pyyaml
  ref:
    sha256sum: d76623373421df22fb4cf8817020cbb7ef15c725b9d5e45f17e189bfc384190f
    suffix: 05/8e/961c0007c59b8dd7729d542c61a4d537767a59645b82a0b521206e1e25c2/pyyaml-6.0.3.tar.gz
config:
  install-commands:
  # pure Python: installing it is copying it, as for meson
  - |
    site=%{install-root}$(python3 -c 'import sysconfig; print(sysconfig.get_path("purelib"))')
    mkdir -p "$site"
    cp -r lib/yaml "$site/"
