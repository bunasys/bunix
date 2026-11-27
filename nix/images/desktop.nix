# The desktop extension: the graphical system, which a machine has when
# its person chooses a desktop and not a console (docs/desktop.md; after
# 0.4.0's elements/sysext/desktop*.bst).  The drivers -- Mesa, libinput,
# seatd -- the text stack and its fonts, niri, the compositor, and the
# shell: DMS on Quickshell and Qt 6, with its login screen under greetd,
# the list of people (accountsservice) and each one's session bus; the
# battery (upower); sound: PipeWire, WirePlumber and alsa-utils, ALSA's
# profiles of sound cards, and the LV2 plugins a Mac's speakers are tuned
# with, and on arm64 Apple's cards' profiles, speakersafetyd and
# asahi-audio (docs/mac-speakers.md); on arm64 too, a MacBook Pro's
# Touch Bar (tiny-dfr, docs/mac-touch-bar.md); the terminal, Alacritty;
# FUSE's libraries and fusermount, with which an AppImage runs; and the
# browser, Hudhud
# (docs/browser.md).  It needs no other extension.
#
#   nix-build /bunix/nix/images/desktop.nix -A image
#
#   signature, version
#           as images/extension.nix takes them
{ system ? builtins.currentSystem, signature ? null, version ? import ../release.nix }:

let
  desktop = import ../desktop.nix { inherit system; };
  browser = import ../browser.nix { inherit system; };
  extension = import ./extension.nix { inherit system signature version; };
  architecture = import ../architecture.nix system;
  qt6Directory = "lib/${architecture.triplet}/qt6";
in
extension {
  name = "desktop";
  contents = [
    desktop.mesa desktop.libinput desktop.seatd desktop.fontconfig desktop.fonts desktop.niri
    desktop.dms desktop.dms-greeter desktop.greetd desktop.accountsservice desktop.upower desktop.dbus-user-session
    desktop.wireplumber desktop.alsa-utils
    desktop.lsp-plugins desktop.bankstown desktop.triforce desktop.alsa-ucm-conf
    desktop.alacritty desktop.libfuse3 desktop.libfuse2
    browser.hudhud
  ]
  # arm64's, whose machines are Macs: the profiles of Apple's sound cards,
  # the speakers' protection and their processing (docs/mac-speakers.md),
  # and the Touch Bar's keys
  ++ (if system == "aarch64-linux" then [ desktop.alsa-ucm-conf-asahi desktop.speakersafetyd desktop.asahi-audio desktop.tiny-dfr ] else []);
  # fusermount3 mounts a FUSE file system for a person who is not root,
  # which takes root's rights; and libfuse 2 runs it by its old name
  # (desktop/libfuse2.sh)
  set_user_id = [ "usr/bin/fusermount3" ];
  # GTK 4's, which Hudhud's file dialogs read their settings through
  gsettings_schemas = true;
  links = [ "bin/fusermount=fusermount3" ];
  # Programs of what these need to run that are for building software
  # against them, not for a desktop.  And libinput's tools that are
  # Python, which the system does not have: `libinput measure`,
  # `analyze`, `replay` and `list-kernel-devices` (its others are C, and
  # stay).
  without = [
    "bin/wayland-scanner" "bin/libpng-config" "bin/libpng16-config"
    "lib/libinput/libinput-analyze-buttons" "lib/libinput/libinput-analyze-per-slot-delta"
    "lib/libinput/libinput-analyze-recording" "lib/libinput/libinput-analyze-touch-down-state"
    "lib/libinput/libinput-list-kernel-devices" "lib/libinput/libinput-measure-fuzz"
    "lib/libinput/libinput-measure-touch-size" "lib/libinput/libinput-measure-touchpad-pressure"
    "lib/libinput/libinput-measure-touchpad-size" "lib/libinput/libinput-measure-touchpad-tap"
    "lib/libinput/libinput-replay"
    # Qt's: its compilers and code generators (moc, qmlcachegen), qmake
    # and the QML tools, and what tells a build of Qt software about Qt
    # -- 35 MB unpacked.  The libraries, plugins and QML modules stay.  The
    # names in bin/ are Qt 6.12's: one a new Qt adds is not left out.
    "${qt6Directory}/bin" "${qt6Directory}/libexec" "${qt6Directory}/mkspecs"
    "${qt6Directory}/metatypes" "${qt6Directory}/modules" "${qt6Directory}/sbom"
    "bin/qmake6" "bin/androiddeployqt6" "bin/harmonydeployqt6" "bin/wasmdeployqt6"
    "bin/qml6" "bin/qmleasing6" "bin/qmlpreview6" "bin/qmlscene6"
  ];
}
