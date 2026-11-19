# A disk with bunix installed on it, as a file: for a virtual machine, and
# as the pattern of what an installer does to a real disk.
#
#   nix-build /bunix/nix/images/disk.nix       (result: disk.raw, usrhash)
#   tools/boot-vm.sh disk                      (on the Mac: builds and boots it)
#
# Three partitions (disk.sh): /usr's image and its hashes, as
# images/system.nix made them, and a root partition, empty but for the
# directories and links a root has.  A machine starts it from
# images/initrd.nix, told the hash of that /usr.
{ system ? builtins.currentSystem }:

let
  tools = import ../tools.nix { inherit system; };
  base = import ../base.nix { inherit system; };
  stagedBuild = import ../stage.nix { inherit system; };
in
stagedBuild {
  name = "bunix-disk";
  run = ./disk.sh;
  # systemd: systemd-repart makes the disk.  e2fsprogs: the root
  # partition's file system.
  buildDepends = [ base.systemd base.e2fsprogs tools.bash tools.coreutils tools.grep tools.sed ];
  env = { system_image = import ./system.nix { inherit system; }; };
}
