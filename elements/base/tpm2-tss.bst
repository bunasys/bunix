kind: autotools
description: |
  tpm2-tss -- the TPM 2.0 software stack.  systemd loads its libraries
  (esys, mu, rc and the /dev/tpmrm0 transport) to measure extension images'
  verity root hashes into the TPM, and later to bind disk encryption to it.
  Without the high-level FAPI (and its JSON, curl and uuid dependencies)
  and the transports for USB and FTDI test adapters.

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/openssl.bst

sources:
- kind: tar
  url: github:tpm2-software/tpm2-tss/releases/download/4.2.1/tpm2-tss-4.2.1.tar.gz
  ref: d4aadbc1610876385a370494bbfd7d994356f446dff60cd09eea5933befb1471

variables:
  # The udev rule gives the tss group /dev/tpm*; sysusers creates the group.
  conf-local: >-
    --disable-static --disable-doxygen-doc
    --disable-fapi --disable-policy --with-crypto=ossl
    --disable-tcti-libtpms --disable-tcti-spi-ltt2go
    --disable-tcti-spi-ftdi --disable-tcti-i2c-ftdi
    --with-udevrulesdir=/usr/lib/udev/rules.d --with-udevrulesprefix=60-
    --with-sysusersdir=/usr/lib/sysusers.d --with-tmpfilesdir=/usr/lib/tmpfiles.d

config:
  install-commands:
    (>):
    # its install makes state directories (/var/run/tpm2-tss, ...) for the
    # FAPI, which is not built; /var is made at boot, not in the image
    - rm -rf %{install-root}/var
    # the tss user its udev rule gives /dev/tpm* to (the install leaves it out
    # when it finds no systemd-sysusers to run), and no rule for the USB
    # adapter that is not built
    - install -D -m 0644 dist/sysusers.d/tpm2-tss.conf %{install-root}/usr/lib/sysusers.d/tpm2-tss.conf
    - rm -f %{install-root}/usr/lib/udev/rules.d/60-ltt2go-udev.rules
