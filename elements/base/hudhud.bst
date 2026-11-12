kind: manual
description: |
  Hudhud (docs/browser.md): the browser (base/chromium.bst), its
  Shields engine and filter lists (base/hudhud-shields.bst), and what makes
  it part of the desktop -- the launcher, the desktop entry and icons, and
  the privacy defaults: recommended policies (the user can change them)
  and first-run preferences.

  A small element on purpose: changing a default or an icon here rebuilds
  this, not Chromium.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

depends:
- base/chromium.bst
- base/hudhud-shields.bst

variables:
  browser-dir: "%{prefix}/lib/hudhud"

config:
  install-commands:
  - |
    # The launcher and the desktop entry
    mkdir -p %{install-root}%{bindir} %{install-root}%{datadir}/applications
    install -m 755 hudhud.sh %{install-root}%{bindir}/hudhud
    cp hudhud.desktop %{install-root}%{datadir}/applications/

  - |
    # The hoopoe icon (files/hudhud/logo): icons/<size>.png for the sizes
    # desktops ask for, and the SVG for any other size
    for png in icons/*.png; do
      size=$(basename $png .png)
      icons=%{install-root}%{datadir}/icons/hicolor/${size}x${size}/apps
      mkdir -p $icons
      cp $png $icons/hudhud.png
    done
    mkdir -p %{install-root}%{datadir}/icons/hicolor/scalable/apps
    cp icons/hudhud.svg %{install-root}%{datadir}/icons/hicolor/scalable/apps/hudhud.svg

  - |
    # Recommended policies, read from here (files/hudhud/patches/
    # 05-policy-path.patch); first-run preferences, read from the
    # browser's own directory
    mkdir -p %{install-root}%{datadir}/hudhud %{install-root}%{browser-dir}
    cp -r policies %{install-root}%{datadir}/hudhud/
    cp initial_preferences %{install-root}%{browser-dir}/

sources:
- kind: local
  path: files/hudhud/install
