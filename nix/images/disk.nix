# A disk with bunix installed on it, as a file: for a virtual machine, and
# as the pattern of what an installer does to a real disk.
#
#   nix-build /bunix/nix/images/disk.nix       (result: disk.raw, usrhash)
#   tools/boot-vm.sh disk                      (on the Mac: builds and boots it)
#
# Its partitions (disk.sh): /usr's image and its hashes, as
# images/system.nix made them; the signature of its hash; and a root
# partition, empty but for the directories and links a root has.  A
# machine starts it from images/initrd.nix, told the hash of that /usr.
#
#   signature  the signature of this system's hash, made with bunix's key
#              (tools/sign.sh has the steps): the disk is then of a system
#              for release.  Without it, the disk is of a test system, and
#              the hash is signed here, by the same script, with the
#              development key, which is not secret
#              (nix/development-key/README).
{ system ? builtins.currentSystem, signature ? null }:

let
  tools = import ../tools.nix { inherit system; };
  base = import ../base.nix { inherit system; };
  stagedBuild = import ../stage.nix { inherit system; };

  signing = if signature == null then "development" else "release";
  systemImage = import ./system.nix { inherit system signing; };
  certificate =
    if signing == "development" then ../development-key/development.crt else ../../keys/verity.crt;

  signingTools = [ base.openssl tools.bash tools.coreutils tools.grep tools.sed ];

  developmentSignature = stagedBuild {
    name = "bunix-development-signature";
    run = ./development-signature.sh;
    buildDepends = signingTools;
    env = {
      sign = ../../tools/sign.sh;
      key = ../development-key/development.key;
      inherit certificate;
      system_image = systemImage;
    };
  };
in
stagedBuild {
  name = "bunix-disk";
  run = ./disk.sh;
  # systemd: systemd-repart makes the disk.  e2fsprogs: the root
  # partition's file system.  openssl: the signature is checked before it
  # is put on the disk.
  buildDepends = [ base.systemd base.e2fsprogs ] ++ signingTools;
  env = {
    system_image = systemImage;
    signature = if signature == null then "${developmentSignature}/signature" else signature;
    inherit certificate;
  };
}
