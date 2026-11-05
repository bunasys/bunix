kind: meson
description: |
  Fontconfig -- finds fonts by name, language and style for every program
  that draws text.  Its configuration is in /usr/share/fontconfig, not
  /etc/fonts: the desktop extension carries only /usr.  With bunix's rule
  for which fonts sans-serif, serif and monospace mean, and a unit that
  rebuilds the font cache (in /var) at every boot.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
- base/gperf.bst

depends:
- base/freetype.bst
- base/expat.bst

sources:
- kind: tar
  url: https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/2.18.3/fontconfig-2.18.3.tar.xz
  ref: 4f7b554a38cdf78c033f666c8871f3749e14a094f65a07f630c91ed0b43d35e3

variables:
  meson-local: >-
    -Ddoc=disabled -Dnls=disabled -Dtests=disabled -Dtools=enabled
    -Dcache-build=disabled -Dxml-backend=expat -Dcache-dir=/var/cache/fontconfig
    -Dbaseconfig-dir=/usr/share/fontconfig -Dconfig-dir=/usr/share/fontconfig/conf.d

config:
  install-commands:
    (>):
    - |
      # Which fonts the generic names mean, from base/fonts-noto.bst and
      # base/fonts-arabic.bst.  58-: read before fontconfig's own
      # 60-latin.conf (the first rule read wins).  Arabic text in a sans-serif
      # page has no glyphs in Noto Sans and falls through to Noto Sans Arabic
      # (it went to Noto Kufi Arabic, a display face, before).
      mkdir -p %{install-root}/usr/share/fontconfig/conf.avail %{install-root}/usr/share/fontconfig/conf.d
      cat > %{install-root}/usr/share/fontconfig/conf.avail/58-bunix-fonts.conf <<'CONF'
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
      <fontconfig>
        <alias><family>sans-serif</family>
          <prefer><family>Noto Sans</family><family>Noto Sans Arabic</family><family>Noto Color Emoji</family></prefer>
        </alias>
        <alias><family>serif</family>
          <prefer><family>Noto Naskh Arabic</family><family>Noto Color Emoji</family></prefer>
        </alias>
        <alias><family>monospace</family>
          <prefer><family>Noto Sans Mono</family><family>Noto Sans Arabic</family><family>Noto Color Emoji</family></prefer>
        </alias>
        <alias><family>emoji</family><prefer><family>Noto Color Emoji</family></prefer></alias>
      </fontconfig>
      CONF
      ln -s ../conf.avail/58-bunix-fonts.conf %{install-root}/usr/share/fontconfig/conf.d/58-bunix-fonts.conf
    - |
      # Fontconfig rescans a font directory only when its time stamp changes,
      # and every directory of a bunix /usr has the same one (reproducible
      # builds): the cache in /var never saw fonts a newer release or the
      # desktop extension brought.  So it is rebuilt at every boot -- a
      # second for a few dozen fonts; a failure leaves the old cache and does
      # not fail the boot ("-").  Upholds=: docs/desktop.md, "Units in an
      # extension".
      units=%{install-root}/usr/lib/systemd/system
      mkdir -p $units/multi-user.target.d
      cat > $units/fontconfig-cache.service <<'UNIT'
      [Unit]
      Description=Fontconfig's font cache
      After=systemd-sysext.service local-fs.target

      [Service]
      Type=oneshot
      RemainAfterExit=yes
      ExecStart=-/usr/bin/fc-cache --force --system-only
      UNIT
      cat > $units/multi-user.target.d/fontconfig-cache.conf <<'UNIT'
      [Unit]
      Upholds=fontconfig-cache.service
      UNIT
