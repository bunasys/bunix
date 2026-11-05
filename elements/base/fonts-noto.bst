kind: manual
description: |
  The desktop's fonts, next to the Arabic fonts of the base
  (base/fonts-arabic.bst): Noto Sans, upright and italic, for Latin, Greek
  and Cyrillic; Noto Sans Arabic, its Arabic companion, for Arabic
  interface and web text; Noto Sans Mono (web pages' code; Ghostty has its
  own); Noto Color Emoji.  Fontconfig prefers them in that order
  (58-bunix-fonts.conf, below).  From the same pinned commit of the Google
  Fonts repository, under the SIL Open Font License.  With the unit that
  refreshes Fontconfig's cache at boot.

build-depends:
- bootstrap/build-env.bst

sources:
- kind: remote
  url: google-fonts:2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/notosans/NotoSans%5Bwdth%2Cwght%5D.ttf
  filename: NotoSans[wdth,wght].ttf
  ref: bfb7bb691513f12e734dc346c03a03f784912432d7e3fa8e56efcf906fe86b3d
  directory: notosans
- kind: remote
  url: google-fonts:2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/notosans/NotoSans-Italic%5Bwdth%2Cwght%5D.ttf
  filename: NotoSans-Italic[wdth,wght].ttf
  ref: 58e6e0ebd1931b29a365aa2d3e2ee9a9e831a3af7cf3ad1462d4e72154f0b291
  directory: notosans
- kind: remote
  url: google-fonts:2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/notosansmono/NotoSansMono%5Bwdth%2Cwght%5D.ttf
  filename: NotoSansMono[wdth,wght].ttf
  ref: 2cb2adb378a8f574213e23df697050b83c54c27df465a2015552740b2769a081
  directory: notosansmono
- kind: remote
  url: google-fonts:2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/notosans/OFL.txt
  filename: OFL.txt
  ref: cee9892f9f0cc8fe882c9e9537ee6a89621d86ee7ceaf70b02e2b2b1c25c061a
  directory: notosans

- kind: remote
  url: google-fonts:2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/notosansarabic/NotoSansArabic%5Bwdth%2Cwght%5D.ttf
  filename: NotoSansArabic[wdth,wght].ttf
  ref: 63111b5b2e074dd48cc67692e0a2726d86ee94c1c37fe8598257b7b4e87e869e
  directory: notosansarabic
- kind: remote
  url: google-fonts:2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/notosansarabic/OFL.txt
  filename: OFL.txt
  ref: 07fc70bfeb985cc1a87a8587d0a0c80bab11c86c9dc3fd95b6f0cb332f983e96
  directory: notosansarabic
- kind: remote
  url: google-fonts:2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/notocoloremoji/NotoColorEmoji-Regular.ttf
  filename: NotoColorEmoji-Regular.ttf
  ref: 4d82a18d8d95f60ba883ce242bbadbf84a576e987745dd7ba38d71c67cff2d73
  directory: notocoloremoji
- kind: remote
  url: google-fonts:2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc/ofl/notocoloremoji/OFL.txt
  filename: OFL.txt
  ref: ac564676d10054a8445923dfc2dfb13c042d97888bd27c1b6ec6dfe89a9d8d62
  directory: notocoloremoji

config:
  install-commands:
  - |
    for family in notosans notosansmono notosansarabic notocoloremoji; do
      install -D -m 0644 -t %{install-root}/usr/share/fonts/$family $family/*.ttf
    done
    for family in notosans notosansarabic notocoloremoji; do
      install -D -m 0644 $family/OFL.txt %{install-root}/usr/share/licenses/fonts-$family/OFL.txt
    done
  - |
    # Which fonts the generic names mean.  58-: read before fontconfig's own
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
    # second for this handful of fonts.  Upholds=: the extension's units
    # arrive after the boot has chosen what to start.
    units=%{install-root}/usr/lib/systemd/system
    mkdir -p $units/multi-user.target.d
    cat > $units/fontconfig-cache.service <<'UNIT'
    [Unit]
    Description=Fontconfig's font cache
    After=systemd-sysext.service local-fs.target

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStart=/usr/bin/fc-cache --force --system-only
    UNIT
    cat > $units/multi-user.target.d/fontconfig-cache.conf <<'UNIT'
    [Unit]
    Upholds=fontconfig-cache.service
    UNIT
