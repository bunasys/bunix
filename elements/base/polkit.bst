kind: meson
description: |
  polkit -- decides which unprivileged user may do which privileged thing
  (run0, rebooting from the desktop, setting the time), from rules in
  JavaScript (Duktape).  Members of the wheel group are administrators:
  polkit asks them for their own password.  Its PAM rules include
  system-auth (files/rootfs/usr/lib/pam.d).

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
# msgfmt merges the actions' descriptions into their .policy files
- base/gettext.bst
# turns the JavaScript init file into a C string
- base/perl.bst

depends:
- base/duktape.bst
- base/expat.bst
- base/glib.bst
- base/linux-pam.bst
- base/systemd.bst

sources:
- kind: tar
  url: github:polkit-org/polkit/archive/refs/tags/128.tar.gz
  ref: 6edb06bf1448e49e428f9597a97af6a05d62146dd0b58f86eeaebcee3f5ecfaa

variables:
  meson-local: >-
    -Dsession_tracking=logind -Dauthfw=pam -Dpam_include=system-auth
    -Dpam_prefix=/usr/lib/pam.d -Dprivileged_group=wheel
    -Dintrospection=false -Dexamples=false -Dtests=false -Dman=false -Dgtk_doc=false
    -Dgettext=false

config:
  install-commands:
    (>):
    # pkexec works only setuid, which this system leaves out: run0 does its job
    - rm %{install-root}/usr/bin/pkexec
