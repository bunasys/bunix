# What a machine with bunix on its disk starts from: a small system in
# memory, systemd's own, whose one job is to find the rest.  It sets up
# /usr from the partitions the kernel's command line names by their hash
# (usrhash=, dm-verity); makes the root partition if the disk has none
# yet (as that /usr says: system/usr/lib/repart.d), mounts it (root=);
# and hands over to the systemd in that /usr.
#
#   nix-build /bunix/nix/images/initrd.nix     (result: initramfs.cpio.gz)
#
# An image as images/system.nix is, of fewer packages: whole packages, as
# every image here is, though it uses a small part of each.  About 55 MB,
# to shrink when packages come in two parts, for running and for building
# against (docs/nix-usr-system.md), not by picking files.
{ system ? builtins.currentSystem }:

let
  toolchain = import ../toolchain.nix { inherit system; };
  tools = import ../tools.nix { inherit system; };
  base = import ../base.nix { inherit system; };
  boot = import ../boot.nix { inherit system; };
  stagedBuild = import ../stage.nix { inherit system; };
in
stagedBuild {
  name = "bunix-initrd";
  run = ./image.sh;

  # systemd, with udev and what sets up dm-verity; what makes the root
  # partition's file system and checks it before it is mounted; and a
  # shell and its tools for a person, should it stop here.
  contents = [
    base.systemd tools.bash tools.coreutils base.util-linux toolchain.gccLibraries
    base.e2fsprogs base.dm-udev-rules tools.sed tools.grep
    # The wireless regulatory database.  Nothing here uses Wi-Fi: the
    # kernel's own Wi-Fi code is built in and asks for the file once, as
    # the kernel starts, when this is the only file system there is.  In
    # /usr alone it is never found, and the kernel says "failed to load
    # regulatory.db".
    base.wireless-regdb
  ];

  buildDepends = [ boot.linux base.systemd tools.bash tools.coreutils tools.findutils tools.grep tools.sed tools.gzip ];
  # initrd/: the file systemd knows this stage by (etc/initrd-release),
  # and a preset that enables nothing.
  env = { bunix_files = ./initrd; };
}
