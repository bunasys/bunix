kind: manual
description: |
  Noto Sans, upright and italic, variable in weight and width: the
  desktop's interface font for Latin, Greek and Cyrillic, next to the
  Arabic fonts (base/fonts-arabic.bst); and Noto Sans Mono, its monospace
  font (web pages' code; Ghostty has its own).  From the same pinned
  commit of the Google Fonts repository, under the SIL Open Font License.
  With the unit that refreshes Fontconfig's cache at boot.

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

config:
  install-commands:
  - |
    install -D -m 0644 -t %{install-root}/usr/share/fonts/notosans notosans/*.ttf
    install -D -m 0644 -t %{install-root}/usr/share/fonts/notosansmono notosansmono/*.ttf
    install -D -m 0644 notosans/OFL.txt %{install-root}/usr/share/licenses/fonts-notosans/OFL.txt
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
