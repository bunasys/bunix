# What differs between the architectures of a bunix system, as far as a
# build of a system package is concerned (stage.nix gives both to every
# build, as $triplet and $loader).
#
#   import ./architecture.nix "aarch64-linux"
#
#   triplet  names the directory of libraries, /usr/lib/<triplet>, as
#            project.conf has it
#   loader   the path every program asks for its loader by; fixed by the
#            architecture's ABI, the same on every distribution
system:

let
  architectures = {
    aarch64-linux = {
      triplet = "aarch64-linux-gnu";
      loader = "/lib/ld-linux-aarch64.so.1";
    };
    x86_64-linux = {
      triplet = "x86_64-linux-gnu";
      loader = "/lib64/ld-linux-x86-64.so.2";
    };
  };
in
if builtins.hasAttr system architectures
then architectures.${system}
else throw "nix/architecture.nix has no entry for ${system}"
