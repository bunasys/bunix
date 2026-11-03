kind: manual
description: |
  Mozilla's CA certificate bundle, as extracted by the curl project -- the
  roots TLS clients (curl, cargo, OpenSSL's default) verify servers against

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

sources:
- kind: remote
  url: curl:ca/cacert-2026-10-20.pem
  filename: cacert.pem
  ref: 796f1389bfea13c0ed78f663b765baaff54a508e5483786bd6ece73c5e3e3cbe

config:
  install-commands:
  - install -D -m 0644 cacert.pem %{install-root}/etc/ssl/certs/ca-certificates.crt
  # OpenSSL's own default location is $OPENSSLDIR/cert.pem
  - ln -s certs/ca-certificates.crt %{install-root}/etc/ssl/cert.pem
