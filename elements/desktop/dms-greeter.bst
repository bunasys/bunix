kind: manual
description: |
  dms-greeter -- DMS's login screen, a greetd greeter: it starts a
  compositor (niri) as the greeter user and, in it, its Quickshell UI,
  embedded in the binary like desktop/dms.bst's.  Pure Go, no cgo.

  Built offline the same way as desktop/dms.bst: the release tarball, the
  dux-qml-common commit its tag pins, and its Go modules as a file module
  proxy (tools/go-modules.py).

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- desktop/go-1.27.bst

# Runs its embedded UI with Quickshell's qs, in niri
depends:
- desktop/quickshell.bst
- desktop/niri.bst
- base/greetd.bst
# its list of users
- desktop/accountsservice.bst

sources:
- kind: tar
  url: github:duxlabs-dev/dux-greeter/archive/refs/tags/v2.1.2.tar.gz
  ref: 29bf015285a63d41df32995d5e4661c3fbb46796a3954dd8427bcf1e1675d5f4
- kind: tar
  url: github:duxlabs-dev/dux-qml-common/archive/b78c6fc861bcf1955d3db0c016779886add1f207.tar.gz
  directory: dux-qml-common
  ref: 01ae26e1ab6329df239395909b5a21066ee74f740cf37a7b5337d121be7873bf
# tools/go-modules.py <dux-greeter v2.1.2>/core ./cmd/dms-greeter withshell (Go 1.27)
- kind: remote
  url: goproxy:github.com/aymanbagabas/go-osc52/v2/@v/v2.0.1.mod
  directory: goproxy/github.com/aymanbagabas/go-osc52/v2/@v
  filename: v2.0.1.mod
  ref: 4646f9f19a822aebf4296bce24d5f2b7b2700ea1c44f5cc978300263cb7b5611
- kind: remote
  url: goproxy:github.com/aymanbagabas/go-osc52/v2/@v/v2.0.1.zip
  directory: goproxy/github.com/aymanbagabas/go-osc52/v2/@v
  filename: v2.0.1.zip
  ref: 939ebf2a5481f2172e1a5e0c318d05aef5b6d950a960556216c3da7879a927f8
- kind: remote
  url: goproxy:github.com/charmbracelet/colorprofile/@v/v0.4.3.mod
  directory: goproxy/github.com/charmbracelet/colorprofile/@v
  filename: v0.4.3.mod
  ref: 4da50dc5179ea48dc7c55db78f05b4911047341ef749027b3969130edf1fd43b
- kind: remote
  url: goproxy:github.com/charmbracelet/colorprofile/@v/v0.4.3.zip
  directory: goproxy/github.com/charmbracelet/colorprofile/@v
  filename: v0.4.3.zip
  ref: 656472ff48f01a098418a31667f3253cf34e04d4e1cb6c1a0a80f76ad370b689
- kind: remote
  url: goproxy:github.com/charmbracelet/lipgloss/@v/v1.1.0.mod
  directory: goproxy/github.com/charmbracelet/lipgloss/@v
  filename: v1.1.0.mod
  ref: 97aa7725695c07aa23c191e2b9d2d3931f367b8a6923ce4a60d969c026138672
- kind: remote
  url: goproxy:github.com/charmbracelet/lipgloss/@v/v1.1.0.zip
  directory: goproxy/github.com/charmbracelet/lipgloss/@v
  filename: v1.1.0.zip
  ref: 22512fd8c211302255bb6f57d8018eed9b8d8f6dd51310512901240bde9b061a
- kind: remote
  url: goproxy:github.com/charmbracelet/log/@v/v1.0.0.mod
  directory: goproxy/github.com/charmbracelet/log/@v
  filename: v1.0.0.mod
  ref: 1514c72ec9685561cae28226d96588c1b88d1c764e3885c5f35e77db4daff7b6
- kind: remote
  url: goproxy:github.com/charmbracelet/log/@v/v1.0.0.zip
  directory: goproxy/github.com/charmbracelet/log/@v
  filename: v1.0.0.zip
  ref: 564622bb814b4c9fc5e18b677d0f3af6b0f532ef0ae862d4c3f0500564c6160a
- kind: remote
  url: goproxy:github.com/charmbracelet/x/ansi/@v/v0.11.9.mod
  directory: goproxy/github.com/charmbracelet/x/ansi/@v
  filename: v0.11.9.mod
  ref: 37eb859ba45ddd27690bfa8d617e8744c37b090e121c03a3b8c8d72b1a3437f5
- kind: remote
  url: goproxy:github.com/charmbracelet/x/ansi/@v/v0.11.9.zip
  directory: goproxy/github.com/charmbracelet/x/ansi/@v
  filename: v0.11.9.zip
  ref: 9815535699efc21636755cc84dbc92250182246e876e4ea83e87464d871cbf82
- kind: remote
  url: goproxy:github.com/charmbracelet/x/cellbuf/@v/v0.0.15.mod
  directory: goproxy/github.com/charmbracelet/x/cellbuf/@v
  filename: v0.0.15.mod
  ref: 5867c27bb93af066945f3c7b5487f721c1f6dc05a382a9e83af0de7ee9ac00f2
- kind: remote
  url: goproxy:github.com/charmbracelet/x/cellbuf/@v/v0.0.15.zip
  directory: goproxy/github.com/charmbracelet/x/cellbuf/@v
  filename: v0.0.15.zip
  ref: 2c5c421edef869c7f4b7b3fa29530a66897134764d95a750eed59ed5886d84f7
- kind: remote
  url: goproxy:github.com/charmbracelet/x/term/@v/v0.2.2.mod
  directory: goproxy/github.com/charmbracelet/x/term/@v
  filename: v0.2.2.mod
  ref: 6df18166815b45f523a79580acfa95f12990a1568e6325f9d60b5825df952962
- kind: remote
  url: goproxy:github.com/charmbracelet/x/term/@v/v0.2.2.zip
  directory: goproxy/github.com/charmbracelet/x/term/@v
  filename: v0.2.2.zip
  ref: 0452a430f7e6882393f81ba19a70a63709960acb9743e1199a7b04d908e6b506
- kind: remote
  url: goproxy:github.com/clipperhouse/displaywidth/@v/v0.11.0.mod
  directory: goproxy/github.com/clipperhouse/displaywidth/@v
  filename: v0.11.0.mod
  ref: 643bf909351d7bc8ff29a8a7bb44cca11efe181ed66e5efe57d695bb023effb3
- kind: remote
  url: goproxy:github.com/clipperhouse/displaywidth/@v/v0.11.0.zip
  directory: goproxy/github.com/clipperhouse/displaywidth/@v
  filename: v0.11.0.zip
  ref: 27830c91cdfb2a648748db21f7a2734dcb50d21c620edde51d488ba4e7967e3d
- kind: remote
  url: goproxy:github.com/clipperhouse/uax29/v2/@v/v2.7.0.mod
  directory: goproxy/github.com/clipperhouse/uax29/v2/@v
  filename: v2.7.0.mod
  ref: f3c5f4e4f9e7fb16aea5fd9dc5f24c3ff9c157b1a67576c0f2140117589507a0
- kind: remote
  url: goproxy:github.com/clipperhouse/uax29/v2/@v/v2.7.0.zip
  directory: goproxy/github.com/clipperhouse/uax29/v2/@v
  filename: v2.7.0.zip
  ref: 67b1278f1ffb4e4d783a390e48fe7396864650138e785d4b4bfca5914333f761
- kind: remote
  url: goproxy:github.com/duxlabs-dev/dux-go/@v/v1.6.3-0.20261020163124-e2ca52bdf500.mod
  directory: goproxy/github.com/duxlabs-dev/dux-go/@v
  filename: v1.6.3-0.20261020163124-e2ca52bdf500.mod
  ref: 9b3d0a550be7d0a1320e716b3308fc6afab708b0956a1c8f2933c1c1900ccfc5
- kind: remote
  url: goproxy:github.com/duxlabs-dev/dux-go/@v/v1.6.3-0.20261020163124-e2ca52bdf500.zip
  directory: goproxy/github.com/duxlabs-dev/dux-go/@v
  filename: v1.6.3-0.20261020163124-e2ca52bdf500.zip
  ref: e034b77eaf9c77d722a4e0252b3f64f11b3f63db1141c512c4572ff807291692
- kind: remote
  url: goproxy:github.com/go-logfmt/logfmt/@v/v0.6.1.mod
  directory: goproxy/github.com/go-logfmt/logfmt/@v
  filename: v0.6.1.mod
  ref: 0b2156771924d6013115a2e80b391afc2ff9d6a22f1bd83a03acf621be39ee4c
- kind: remote
  url: goproxy:github.com/go-logfmt/logfmt/@v/v0.6.1.zip
  directory: goproxy/github.com/go-logfmt/logfmt/@v
  filename: v0.6.1.zip
  ref: 20f61151ffe33e64602b3a0db4eaed9ef60a84398a4a495a7434ffb90635751b
- kind: remote
  url: goproxy:github.com/lucasb-eyer/go-colorful/@v/v1.4.1.mod
  directory: goproxy/github.com/lucasb-eyer/go-colorful/@v
  filename: v1.4.1.mod
  ref: 84f9c38e9884ab013c837cb16aee139500d3d5c6ccab02439881db2ecf28f660
- kind: remote
  url: goproxy:github.com/lucasb-eyer/go-colorful/@v/v1.4.1.zip
  directory: goproxy/github.com/lucasb-eyer/go-colorful/@v
  filename: v1.4.1.zip
  ref: 399a71ecf3e3aaa0af96a779f1c106688b095dbfd0a85455a7c706d3d7ff9ebd
- kind: remote
  url: goproxy:github.com/mattn/go-isatty/@v/v0.0.24.mod
  directory: goproxy/github.com/mattn/go-isatty/@v
  filename: v0.0.24.mod
  ref: 41b885f68c2fa4dfb26a8ffa30d095a931b27699b6b2b1974af3949400dc060f
- kind: remote
  url: goproxy:github.com/mattn/go-isatty/@v/v0.0.24.zip
  directory: goproxy/github.com/mattn/go-isatty/@v
  filename: v0.0.24.zip
  ref: 4fcffec0bae0ad4af7bf96e2497a817d85de64af19ffe31d82bda362148234b8
- kind: remote
  url: goproxy:github.com/mattn/go-runewidth/@v/v0.0.31.mod
  directory: goproxy/github.com/mattn/go-runewidth/@v
  filename: v0.0.31.mod
  ref: 9091c793e255036ba8ced617fa3225972a745eaee5cad4cf264c1576e5c1347e
- kind: remote
  url: goproxy:github.com/mattn/go-runewidth/@v/v0.0.31.zip
  directory: goproxy/github.com/mattn/go-runewidth/@v
  filename: v0.0.31.zip
  ref: 96e004d61b6755f0190ae250c3ce8aa2d2e73968d0b31236f4dc54477d65bc00
- kind: remote
  url: goproxy:github.com/muesli/termenv/@v/v0.16.0.mod
  directory: goproxy/github.com/muesli/termenv/@v
  filename: v0.16.0.mod
  ref: 07581751f5b61fdae253960c3992898b64b6ad5573a69ba22ad249d7f0a889c1
- kind: remote
  url: goproxy:github.com/muesli/termenv/@v/v0.16.0.zip
  directory: goproxy/github.com/muesli/termenv/@v
  filename: v0.16.0.zip
  ref: ba02d3ebd9c1d87e2c2133b1f2bb61a7001b3765196e8016029ce9fe54c5c0fc
- kind: remote
  url: goproxy:github.com/rivo/uniseg/@v/v0.4.7.mod
  directory: goproxy/github.com/rivo/uniseg/@v
  filename: v0.4.7.mod
  ref: a1e174890fc9f252450211fadeb53756f9cf5ab7b19697765f9fb255f81ea898
- kind: remote
  url: goproxy:github.com/rivo/uniseg/@v/v0.4.7.zip
  directory: goproxy/github.com/rivo/uniseg/@v
  filename: v0.4.7.zip
  ref: b995e4aa0cc1e5779cc61138ac925cb8c1e963e40c80e4b93ee8553812ebb792
- kind: remote
  url: goproxy:github.com/sblinch/kdl-go/@v/v0.0.0-20260121213736-8b7053306ca6.mod
  directory: goproxy/github.com/sblinch/kdl-go/@v
  filename: v0.0.0-20260121213736-8b7053306ca6.mod
  ref: 2890c7a09e2a16f2d7e6501130f0f9fb70a307f1a16e92a8db02eed186639ee9
- kind: remote
  url: goproxy:github.com/sblinch/kdl-go/@v/v0.0.0-20260121213736-8b7053306ca6.zip
  directory: goproxy/github.com/sblinch/kdl-go/@v
  filename: v0.0.0-20260121213736-8b7053306ca6.zip
  ref: c2093f820c504766aa58d3f2fa56c716f91ad5ab5e2717482f90820efa3e80ff
- kind: remote
  url: goproxy:github.com/spf13/cobra/@v/v1.10.2.mod
  directory: goproxy/github.com/spf13/cobra/@v
  filename: v1.10.2.mod
  ref: cc6098fd1118fb3bb349c72bcd6e9c665d3a1b2a516ea9807ee24521ad2ddf8c
- kind: remote
  url: goproxy:github.com/spf13/cobra/@v/v1.10.2.zip
  directory: goproxy/github.com/spf13/cobra/@v
  filename: v1.10.2.zip
  ref: a00aae6fcd631e0fde52c98604452ff70e1b73c3b8a560d68db15aff5e26872d
- kind: remote
  url: goproxy:github.com/spf13/pflag/@v/v1.0.10.mod
  directory: goproxy/github.com/spf13/pflag/@v
  filename: v1.0.10.mod
  ref: 16c6dfc0eb58eb3c9113ce197d460c6725c647e4688ac26d31c8ed69f1ebbc68
- kind: remote
  url: goproxy:github.com/spf13/pflag/@v/v1.0.10.zip
  directory: goproxy/github.com/spf13/pflag/@v
  filename: v1.0.10.zip
  ref: a246b8c9d3daa87d6c634cdfee1bdf7fa53d5817eeef4fa0c6da43edd12de4ca
- kind: remote
  url: goproxy:github.com/xo/terminfo/@v/v1.2.0.mod
  directory: goproxy/github.com/xo/terminfo/@v
  filename: v1.2.0.mod
  ref: 12b94fc7704c723ed862da212257099bacb248ad07eeeb03da5d7cba9f8871e4
- kind: remote
  url: goproxy:github.com/xo/terminfo/@v/v1.2.0.zip
  directory: goproxy/github.com/xo/terminfo/@v
  filename: v1.2.0.zip
  ref: 90294795cef18ff941af0d4bf314a685c864818308212d7594716b4d682bb07b
- kind: remote
  url: goproxy:golang.org/x/sys/@v/v0.49.0.mod
  directory: goproxy/golang.org/x/sys/@v
  filename: v0.49.0.mod
  ref: 9522f4c9806d1c26586ea80fa56292929bd295865e71981927f52996c6b1c831
- kind: remote
  url: goproxy:golang.org/x/sys/@v/v0.49.0.zip
  directory: goproxy/golang.org/x/sys/@v
  filename: v0.49.0.zip
  ref: e73a06591ca0d7016ce3ccb45c36a8ed7128468aecc1a357f94d815c760c6b31

environment:
  PATH: "%{prefix}/lib/go-1.27/bin:/usr/bin"
  GOPROXY: "file://%{build-root}/goproxy"
  GOMODCACHE: "%{build-root}/.gomodcache"
  GOCACHE: "%{build-root}/.gocache"
  # go.sum is the check: no checksum database to ask offline
  GOSUMDB: "off"

config:
  build-commands:
  # The version and commit, which the Makefile asks git for (the tarball has
  # no .git), and a fixed build time, so equal sources give an equal binary
  - make -C core build VERSION=2.1.2 COMMIT=v2.1.2 BUILD_TIME=v2.1.2

  install-commands:
  - make install-bin PREFIX=%{prefix} DESTDIR=%{install-root}

  # greetd's configuration (/usr/share/greetd/config.toml, base/greetd.bst):
  # on tty1, dms-greeter as the "greeter" user, in niri; its output to the
  # journal, not onto the console.  A login starts the session the person
  # picks from /usr/share/wayland-sessions (niri's, desktop/niri.bst).
  - |
    install -d %{install-root}%{datadir}/greetd
    cat > %{install-root}%{datadir}/greetd/config.toml <<'TOML'
    [terminal]
    vt = 1

    [default_session]
    command = "systemd-cat --identifier=dms-greeter dms-greeter --command niri"
    user = "greeter"
    TOML

  # US and Arabic keyboards on the login screen, Alt+Shift switches, as in
  # the desktop: dms-greeter adds this file to its own niri configuration
  - |
    cat > %{install-root}%{datadir}/greetd/niri_overrides.kdl <<'KDL'
    input {
        keyboard {
            xkb {
                layout "us,ara"
                options "grp:alt_shift_toggle"
            }
        }
    }
    KDL

  # Its cache in /var/cache/dms-greeter, where dms-greeter keeps the theme
  # and its memory of the last session: made by systemd-tmpfiles, which
  # refuses to follow a symlink the greeter user has put in its own
  # directory (root running chown or install there would follow it, to /etc
  # say).  Run before greetd starts the greeter, after greetd's own sysusers
  # makes the user: the boot's tmpfiles run before this extension is merged.
  # Not fatal ("-"): the greeter starts without its cache.
  # Niri, with DMS, is the session picked until someone picks another: the
  # greeter would take the first it finds (Hyprland), so its memory starts
  # out as niri's.  `f` writes it, owned by the greeter, only when there is
  # none.
  - |
    install -d %{install-root}%{prefix}/lib/tmpfiles.d
    cat > %{install-root}%{prefix}/lib/tmpfiles.d/dms-greeter.conf <<'CONF'
    d /var/cache/dms-greeter 2770 greeter greeter -
    d /var/cache/dms-greeter/.local 0750 greeter greeter -
    d /var/cache/dms-greeter/.local/state 0750 greeter greeter -
    f /var/cache/dms-greeter/.local/state/memory.json 0644 greeter greeter - {"lastSessionDesktopId": "niri.desktop"}
    CONF
    dropin=%{install-root}%{prefix}/lib/systemd/system/greetd.service.d
    install -d $dropin
    cat > $dropin/dms-greeter.conf <<'UNIT'
    [Service]
    ExecStartPre=-/usr/bin/systemd-tmpfiles --create /usr/lib/tmpfiles.d/dms-greeter.conf
    UNIT
  # Its build info, as in desktop/dms.bst: the program is not run in the sandbox
  - go version -m %{install-root}%{bindir}/dms-greeter | grep -q -- '-tags=withshell'
