# The desktop extension: the graphical system, which a machine has when
# its person chooses a desktop and not a console (docs/desktop.md; after
# elements/sysext/desktop*.bst).  So far the drivers -- Mesa, libinput,
# seatd -- the text stack and niri, the compositor: what puts a desktop
# on the screen.  The shell, its login screen, sound and the terminal
# come next.  It needs no other extension.
#
#   nix-build /bunix/nix/images/desktop.nix -A image
#
#   signature, version
#           as images/extension.nix takes them
{ system ? builtins.currentSystem, signature ? null, version ? import ../release.nix }:

let
  desktop = import ../desktop.nix { inherit system; };
  extension = import ./extension.nix { inherit system signature version; };
in
extension {
  name = "desktop";
  contents = [ desktop.mesa desktop.libinput desktop.seatd desktop.fontconfig desktop.niri ];
  # Programs of what these need to run that are for building software
  # against them, not for a desktop.
  without = [ "bin/wayland-scanner" "bin/libpng-config" "bin/libpng16-config" ];
}
