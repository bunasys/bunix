kind: manual
description: pefile -- PE file handling in Python; ukify assembles unified kernel images with it (a build tool)

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

depends:
- base/python.bst

sources:
- kind: pypi
  url: "pypi:"
  name: pefile
  ref:
    sha256sum: 3ff6c5d8b43e8c37bb6e6dd5085658d658a7a0bdcd20b6a07b1fcfc1c4e9d632
    suffix: 03/4f/2750f7f6f025a1507cd3b7218691671eecfd0bbebebe8b39aa0fe1d360b8/pefile-2024.8.26.tar.gz

config:
  install-commands:
  # pure Python: installing it is copying it
  - |
    site=%{install-root}$(python3 -c 'import sysconfig; print(sysconfig.get_path("purelib"))')
    mkdir -p "$site"
    cp -r pefile.py peutils.py ordlookup "$site/"
