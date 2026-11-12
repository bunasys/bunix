kind: manual
description: |
  Buna Browser (docs/browser.md): the browser (base/chromium.bst), its
  Shields engine and filter lists (base/buna-shields.bst), and what makes
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
- base/buna-shields.bst

variables:
  browser-dir: "%{prefix}/lib/buna-browser"

config:
  install-commands:
  - |
    # The launcher and the desktop entry
    mkdir -p %{install-root}%{bindir} %{install-root}%{datadir}/applications
    install -m 755 buna-browser.sh %{install-root}%{bindir}/buna-browser
    cp buna-browser.desktop %{install-root}%{datadir}/applications/

  - |
    # icons/<size>.png, as tools/render-branding.sh makes them
    for png in icons/*.png; do
      size=$(basename $png .png)
      icons=%{install-root}%{datadir}/icons/hicolor/${size}x${size}/apps
      mkdir -p $icons
      cp $png $icons/buna-browser.png
    done

  - |
    # Recommended policies, read from here (files/buna-browser/patches/
    # 05-policy-path.patch); first-run preferences, read from the
    # browser's own directory
    mkdir -p %{install-root}%{datadir}/buna-browser %{install-root}%{browser-dir}
    cp -r policies %{install-root}%{datadir}/buna-browser/
    cp initial_preferences %{install-root}%{browser-dir}/

sources:
- kind: local
  path: files/buna-browser/install
