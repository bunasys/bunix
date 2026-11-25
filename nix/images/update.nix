# One version of bunix as the files a machine downloads to become it
# (docs/updates.md; after elements/system/usr.bst and tools/publish.sh's
# list):
#
#   bunix_<version>.usr-<architecture>.<id>.raw             /usr's image
#   bunix_<version>.usr-<architecture>-verity.<id>.raw      the hashes of its blocks
#   bunix_<version>.usr-<architecture>-verity-sig.<id>.raw  its root hash, signed
#   bunix_<version>.<architecture>.efi                      the kernel image that starts it
#
#   nix-build /bunix/nix/images/update.nix
#
# The first three are the contents of a /usr slot's partitions, and each
# <id> the id its partition is to have: systemd-sysupdate writes them into
# the slot that is not running (system/usr/lib/sysupdate.d), and
# images/disk.nix puts the same files into a new disk's first slot.
#
# Not here: the list of these files with their hashes (SHA256SUMS), which
# says until when it is good, and its signature.  Both are made when a
# version is published, by what has the day and the release key.
#
#   signature  the signature of this system's hash, made with bunix's key
#              (tools/sign.sh has the steps): the files are then of a
#              system for release.  Without it, they are of a test system,
#              and the hash is signed here, by the same script, with the
#              development key, which is not secret
#              (nix/development-key/README).
#   version    the system's, as images/system.nix takes it
#   secureBootLoader
#              x86, a release's: systemd-boot signed for Secure Boot, as
#              images/system.nix takes it (tools/publish.sh makes it)
{ system ? builtins.currentSystem, signature ? null, version ? import ../release.nix
, secureBootLoader ? null }:

let
  tools = import ../tools.nix { inherit system; };
  base = import ../base.nix { inherit system; };
  stagedBuild = import ../stage.nix { inherit system; };
  architecture = import ../architecture.nix system;

  signing = if signature == null then "development" else "release";
  systemImage = import ./system.nix { inherit system signing version secureBootLoader; };
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
      hash_file = "${systemImage}/usr-partition/usrhash";
    };
  };
in
stagedBuild {
  # the result says in its name whose signatures the system in it takes:
  # a test system's files are named as a release's are, and are not to
  # be published
  name = "bunix-update-${version}-${signing}";
  run = ./update.sh;
  # openssl: the signature is checked before it is one of the files
  buildDepends = signingTools;
  env = {
    system_image = systemImage;
    uki = import ./uki.nix { inherit system signing version secureBootLoader; };
    signature = if signature == null then "${developmentSignature}/signature" else signature;
    inherit certificate;
    signature_check = ./signature-check.sh;
    partition_architecture = architecture.partitionArchitecture;
  };
}
