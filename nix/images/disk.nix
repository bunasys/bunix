# A disk with bunix installed on it, as a file: for a virtual machine, and
# as the pattern of what an installer does to a real disk.  After
# elements/system/disk.bst.
#
#   nix-build /bunix/nix/images/disk.nix       (result: disk.raw)
#   tools/boot-vm.sh disk                      (on the Mac: builds and boots it)
#
# Its partitions (disk.sh), by the Discoverable Partitions Specification:
#
#   ESP          systemd-boot, and images/uki.nix, which it starts
#   /usr slot A  this system (images/system.nix): its image, the hashes
#                of its blocks, the signature of its hash
#   /usr slot B  empty, for the next update
#   root         none yet: systemd-repart makes it on the first boot, in
#                the space after these, and grows it to the end of the disk
#
# A machine with EFI starts it.  A virtual machine's has; a Mac's, which
# is to be U-Boot's, has not started one yet.  For a disk that is bunix's
# alone (system/usr/lib/repart.d/50-root.conf says why).
#
#   signature  the signature of this system's hash, made with bunix's key
#              (tools/sign.sh has the steps): the disk is then of a system
#              for release.  Without it, the disk is of a test system, and
#              the hash is signed here, by the same script, with the
#              development key, which is not secret
#              (nix/development-key/README).
#   espSize    the partition a machine boots from.  A kernel image is
#              about 100 MB, and an update keeps the one before beside
#              the new one: 1G, as x86 has for its kernel images.
#   usrSlotSize, usrVeritySize
#              a /usr slot: room for /usr to grow over later versions, and
#              for the hashes of that much (1/128 of it, and as much
#              again).  Twice x86's 1G and 16M.
#
# A test can ask for less of all three, to have less to build and copy:
# the disk, at these sizes, is over 5 GB, whole in the builder's store for
# every system it is built of.
{ system ? builtins.currentSystem, signature ? null
, espSize ? "1G", usrSlotSize ? "2G", usrVeritySize ? "32M" }:

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
  # systemd: systemd-repart makes the disk, and systemd-boot goes on it.
  # dosfstools and mtools: the ESP's file system, and what fills it.
  # openssl: the signature is checked before it is put on the disk.
  buildDepends = [ base.systemd base.dosfstools base.mtools tools.findutils ] ++ signingTools;
  env = {
    system_image = systemImage;
    uki = import ./uki.nix { inherit system signing; };
    signature = if signature == null then "${developmentSignature}/signature" else signature;
    inherit certificate;
    esp_size = espSize;
    usr_slot_size = usrSlotSize;
    usr_verity_size = usrVeritySize;
  };
}
