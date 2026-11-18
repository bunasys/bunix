# The first bunix system that boots, as an initramfs: an archive the kernel
# unpacks into memory and runs /init from.
#
#   nix-build /bunix/nix/images/initramfs.nix     (result: initramfs.cpio.gz)
#   tools/boot-vm.sh                              (on the Mac: builds and boots it)
#
# It is the usr/ and etc/ of `contents`, and of everything they need to
# run, laid over each other as one root: /usr/bin/bash, /usr/lib/<triplet>/
# libc.so.6.  There is no /nix in it.
{ system ? builtins.currentSystem }:

let
  stage2 = import ../stage2.nix { inherit system; };
  tools = import ../tools.nix { inherit system; };
  base = import ../base.nix { inherit system; };
  bunix = import ../system.nix { inherit system; };

  stagedBuild = import ../stage.nix {
    inherit system;
    shell = "${stage2.bash}/bin/bash";
    stagingTools = stage2.all ++ [ stage2.util-linux ];
  };
in
stagedBuild {
  name = "bunix-initramfs";
  run = ./initramfs.sh;
  # what the system has
  contents = [ tools.bash tools.coreutils base.util-linux ];
  # What packs it.  gen_init_cpio comes with the kernel.
  buildDepends = [ bunix.linux tools.bash tools.coreutils tools.findutils tools.sed tools.grep tools.gzip ];
  env = { init = ./init.sh; };
}
