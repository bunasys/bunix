kind: manual
description: |
  packaging -- version parsing for Mesa's build

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

sources:
- kind: pypi
  url: "pypi:"
  name: packaging
  ref:
    sha256sum: 94edc256424af38762eb31306eed28beb9f0efc50a8837492c9d6fd6004aed79
    suffix: 7d/fa/3944b40b07da9ce895c0e6303a5ab7d53da063554f534556b134a54d6093/packaging-26.3.tar.gz
config:
  install-commands:
  # pure Python: installing it is copying it, as for meson
  - |
    site=%{install-root}$(python3 -c 'import sysconfig; print(sysconfig.get_path("purelib"))')
    mkdir -p "$site"
    cp -r src/packaging "$site/"
