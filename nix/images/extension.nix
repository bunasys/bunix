# A system extension: programs a machine does not need to run, which its
# person asks for, as one image that systemd-sysext lays over /usr
# (docs/updates.md; after include/sysext-image.yml and
# elements/sysext/*-tree.bst).  images/devtools.nix is one, and shows the
# call.
#
#   <name>_<version>.<architecture>.raw
#
# The image is a small disk of three partitions, as a /usr slot is three:
# a read-only file system with usr/ in it, the hashes of its blocks, and
# its root hash, signed.  A system merges such an image only if the
# signature is of a key it takes (system/usr/lib/systemd/sysext.conf.d),
# and only into the version it was made for: its libraries are that
# system's.
#
# The architecture is in the file's name, where x86's had none: the two
# are published side by side.
#
# What a caller gets is two results:
#
#   parts   the file system, its hashes and the root hash (roothash),
#           before anything is signed.  The same whoever signs.
#   image   the extension, with the signature in it
#
# An extension for release, on a Mac with the builder of
# tools/nix-builder/lima.yaml, as tools/sign.sh has it for a system:
#
#   parts=$(limactl shell bunix-builder nix-build /bunix/nix/images/devtools.nix \
#       -A parts --no-out-link)
#   tools/sign.sh $(limactl shell bunix-builder cat $parts/roothash) > out/devtools-signature
#   limactl shell bunix-builder nix-build /bunix/nix/images/devtools.nix \
#       -A image --arg signature /bunix/out/devtools-signature --no-out-link
#
#   signature, version
#           as images/update.nix takes them
{ system ? builtins.currentSystem, signature ? null, version ? import ../release.nix }:

# name      what the extension is called: of small letters and digits,
#           since sysext takes a file's name up to the first "_" for it
# contents  the packages it brings.  What they need to run comes with
#           them, but for what the system has already.
# without   paths under usr/ that it is not to have, files or
#           directories: programs of the packages its own need, which are
#           not what it is for
# keep      paths under usr/ that it keeps of what every extension is
#           stripped of: headers, static libraries, pkg-config and cmake
#           files (extension-parts.sh)
# links     names it adds for programs it has, each "name=program", the
#           name a path under usr/ (bin/cc=clang)
{ name, contents, without ? [], keep ? [], links ? [] }:

assert builtins.match "[a-z0-9]+" name != null;

let
  tools = import ../tools.nix { inherit system; };
  base = import ../base.nix { inherit system; };
  stagedBuild = import ../stage.nix { inherit system; };
  architecture = import ../architecture.nix system;

  signing = if signature == null then "development" else "release";
  certificate =
    if signing == "development" then ../development-key/development.crt else ../../keys/verity.crt;

  signingTools = [ base.openssl tools.bash tools.coreutils tools.grep tools.sed ];

  parts = stagedBuild {
    name = "bunix-${name}-parts-${version}";
    run = ./extension-parts.sh;
    inherit contents;
    # systemd: repart makes the hashes.  erofs-utils: the file system.
    buildDepends = [ base.systemd base.erofs-utils tools.bash tools.coreutils tools.tar tools.findutils tools.grep tools.sed ];
    env = {
      extension = name;
      # For the list of what /usr has.  The test system's, whoever signs:
      # a system for release differs from it by one certificate, which no
      # extension has, and so the parts do not depend on the signature
      # that is made of them.
      system_image = import ./system.nix { inherit system version; };
      partition_architecture = architecture.partitionArchitecture;
      inherit version without keep links;
    };
  };

  developmentSignature = stagedBuild {
    name = "bunix-${name}-development-signature";
    run = ./development-signature.sh;
    buildDepends = signingTools;
    env = {
      sign = ../../tools/sign.sh;
      key = ../development-key/development.key;
      inherit certificate;
      hash_file = "${parts}/roothash";
    };
  };

  image = stagedBuild {
    # as an update's files: the name says whose signatures the system it
    # is for takes
    name = "bunix-${name}-${version}-${signing}";
    run = ./extension.sh;
    # openssl: the signature is checked before it is in the image
    buildDepends = signingTools ++ [ base.systemd ];
    env = {
      extension = name;
      inherit parts certificate version;
      signature = if signature == null then "${developmentSignature}/signature" else signature;
      signature_check = ./signature-check.sh;
      partition_architecture = architecture.partitionArchitecture;
    };
  };
in
{ inherit parts image; }
