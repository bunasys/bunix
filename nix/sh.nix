# /bin/sh, the one program a build sees outside the store: the seed's bash,
# copied into a store path of its own.
#
#   nix-build /bunix/nix/sh.nix
#
# tools/nix-builder/nix.conf names the result in sandbox-paths.  Nix shows
# a build the whole store path that such a file is part of, so naming the
# seed's own bin/bash would put the entire seed in every build, declared or
# not.  This store path holds the one file.
{ system ? builtins.currentSystem }:

let
  seed = import ./seed.nix { inherit system; };
in
derivation {
  name = "sh";
  inherit system;
  builder = "${seed}/bin/bash";
  args = [ "-c" "${seed}/bin/cp ${seed}/bin/bash $out" ];
}
