# The devtools extension: tools for working on software and on a running
# system -- git, gdb, strace, file, and libarchive's bsdtar and unzip
# (after elements/sysext/devtools-content.bst) -- and Nix, which bunix
# is built by.  On x86_64 also Firecracker, for microVMs (base.nix says
# why only there).  It needs no other extension.
#
#   nix-build /bunix/nix/images/devtools.nix -A image
#
#   signature, version
#           as images/extension.nix takes them
{ system ? builtins.currentSystem, signature ? null, version ? import ../release.nix }:

let
  base = import ../base.nix { inherit system; };
  extension = import ./extension.nix { inherit system signature version; };
in
extension {
  name = "devtools";
  contents = [ base.git base.gdb base.strace base.file base.libarchive base.nix ]
    ++ (if system == "x86_64-linux" then [ base.firecracker ] else []);
  # Programs of what these need to run (ncurses, curl, expat, openssl,
  # bzip2), where the system does not have them already: not tools this
  # extension is for.  The element's list.
  without = [
    "bin/tic" "bin/infocmp" "bin/toe" "bin/tabs" "bin/captoinfo" "bin/infotocap" "bin/ncurses6-config"
    "bin/curl-config" "bin/xmlwf" "bin/c_rehash"
    "bin/bzip2" "bin/bunzip2" "bin/bzcat" "bin/bzip2recover" "bin/bzdiff" "bin/bzgrep" "bin/bzmore"
    "bin/bzless" "bin/bzcmp" "bin/bzegrep" "bin/bzfgrep"
  ];
}
