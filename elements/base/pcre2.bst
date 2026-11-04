kind: autotools
description: |
  PCRE2 -- Perl-compatible regular expressions: grep -P, and later GLib

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: github:PCRE2Project/pcre2/releases/download/pcre2-10.49/pcre2-10.49.tar.bz2
  ref: 53c156e1ba416a20da8e65395daa132da0d80e76910424caca3fcdae7831d384

variables:
  conf-local: --disable-static --enable-jit
