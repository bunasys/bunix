# The first bunix system that boots: an initramfs with a shell and the
# usual commands, for the kernel of packages.nix.
#
#   nix-build /bunix/nix/initramfs.nix        (the result is initramfs.cpio.gz)
#   tools/boot-vm.sh                          (on the Mac: builds and boots it)
#
# An initramfs is an archive the kernel unpacks into memory and runs
# /init from.  This one holds the store paths of `contents` and of
# everything they need to run, at the same /nix/store/... paths they have
# here, so nothing in them has to be told it moved.
{ system ? builtins.currentSystem }:

let
  stage2 = import ./stage2.nix { inherit system; };
  stage3 = import ./stage3.nix { inherit system; };
  packages = import ./packages.nix { inherit system; };

  # what the system has; its commands are on PATH in this order
  contents = [ packages.bash packages.coreutils packages.utilLinux stage3.glibc ];

  # the tools that pack it: gen_init_cpio comes with the kernel
  tools = [ packages.linux ] ++ stage2.all;
in
derivation {
  name = "initramfs.cpio.gz";
  inherit system;
  builder = "${stage2.bash}/bin/bash";
  args = [ ./initramfs.sh ];
  PATH = builtins.concatStringsSep ":" (map (tool: "${tool}/bin") tools);

  inherit contents;
  shell = packages.bash;
  init = ./init.sh;

  # For each of the contents, Nix writes a file closure-<name> in the build
  # directory: every store path it needs to run, itself included.  The
  # attribute is a list of file name, package, file name, package...
  exportReferencesGraph =
    builtins.concatLists (map (package: [ "closure-${package.name}" package ]) contents);
}
