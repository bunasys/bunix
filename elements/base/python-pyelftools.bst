kind: manual
description: pyelftools -- ELF parsing in Python; systemd's build turns systemd-boot's ELF binaries into EFI ones with it

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

depends:
- base/python.bst

sources:
- kind: pypi
  url: "pypi:"
  name: pyelftools
  ref:
    sha256sum: 660d82dcbeb8e83d1702bd97f223f761625da06111c0cc988eac6b8ab0c1b61f
    suffix: a3/11/767522582afab1b884d277de0e6e011640cb9d7292a38694b4b1a1df1ae8/pyelftools-0.33.tar.gz

config:
  install-commands:
  # pure Python: installing it is copying it, as for meson
  - |
    site=%{install-root}$(python3 -c 'import sysconfig; print(sysconfig.get_path("purelib"))')
    mkdir -p "$site"
    cp -r elftools "$site/"
