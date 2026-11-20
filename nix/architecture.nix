# What differs between the architectures of a bunix system: for a build
# of a system package, the first two (stage.nix gives them to every
# build, as $triplet and $loader); for what makes images, the third.
#
#   import ./architecture.nix "aarch64-linux"
#
#   triplet  names the directory of libraries, /usr/lib/<triplet>, as
#            project.conf has it
#   loader   the path every program asks for its loader by; fixed by the
#            architecture's ABI, the same on every distribution
#   partitionArchitecture
#            the architecture as the types of partitions name it
#            (usr-arm64), and as systemd does for %a in the files that
#            say where updates come from; in the names of update files
system:

let
  architectures = {
    aarch64-linux = {
      triplet = "aarch64-linux-gnu";
      loader = "/lib/ld-linux-aarch64.so.1";
      partitionArchitecture = "arm64";
    };
    x86_64-linux = {
      triplet = "x86_64-linux-gnu";
      loader = "/lib64/ld-linux-x86-64.so.2";
      partitionArchitecture = "x86-64";
    };
  };
in
if builtins.hasAttr system architectures
then architectures.${system}
else throw "nix/architecture.nix has no entry for ${system}"
