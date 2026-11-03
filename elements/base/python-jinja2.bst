kind: manual
description: Jinja2 -- the template engine systemd's build generates files with

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

depends:
- base/python-markupsafe.bst

sources:
- kind: pypi
  url: "pypi:"
  name: jinja2
  ref:
    sha256sum: 0137fb05990d35f1275a587e9aee6d56da821fc83491a0fb838183be43f66d6d
    suffix: df/bf/f7da0350254c0ed7c72f3e33cef02e048281fec7ecec5f032d4aac52226b/jinja2-3.1.6.tar.gz
config:
  install-commands:
  # pure Python: installing it is copying it, as for meson
  - |
    site=%{install-root}$(python3 -c 'import sysconfig; print(sysconfig.get_path("purelib"))')
    mkdir -p "$site"
    cp -r src/jinja2 "$site/"
