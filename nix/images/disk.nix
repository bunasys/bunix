# A disk with bunix installed on it, as a file: for a virtual machine, and
# as the pattern of what an installer does to a real disk.  After
# elements/system/disk.bst.
#
#   nix-build /bunix/nix/images/disk.nix       (result: disk.raw)
#   tools/boot-vm.sh disk                      (on the Mac: builds and boots it)
#
# Its partitions (disk.sh), by the Discoverable Partitions Specification:
#
#   ESP          systemd-boot, and the kernel image, which it starts
#   /usr slot A  this system: its image, the hashes of its blocks, the
#                signature of its hash
#   /usr slot B  empty, for the next update
#   root         none yet: systemd-repart makes it on the first boot, in
#                the space after these, and grows it to the end of the disk
#
# A machine with EFI starts it.  A virtual machine's has; a Mac's, which
# is U-Boot's, has not started one yet (docs/nix-usr-system.md, "A Mac
# starts from its disk").  For a disk that is bunix's
# alone (system/usr/lib/repart.d/50-root.conf says why).
#
# What goes on it is images/update.nix: the files a machine downloads to
# become this version, so a disk and an update of one version are the same
# to the byte.
#
#   signature, version
#              as images/update.nix takes them: of a system for release,
#              or, without a signature, a test system
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
#
#   secureBootEnrolment
#              true for a test machine that is to start with Secure Boot
#              on (tools/secure-boot-test.sh; x86, and a test system):
#              systemd-boot is signed with the development key, as the
#              kernel image of a test system is, and gives the machine's
#              firmware that key at the first start
#              (secure-boot-enrolment.sh).  Not for a real machine: its
#              owner's keys are not this disk's to replace.  A Mac has no
#              Secure Boot.
{ system ? builtins.currentSystem, signature ? null, version ? import ../release.nix
, espSize ? "1G", usrSlotSize ? "2G", usrVeritySize ? "32M", secureBootEnrolment ? false }:

assert secureBootEnrolment -> (signature == null && system == "x86_64-linux");

let
  tools = import ../tools.nix { inherit system; };
  base = import ../base.nix { inherit system; };
  stagedBuild = import ../stage.nix { inherit system; };
  architecture = import ../architecture.nix system;

  developmentKey = ../development-key/development.key;
  developmentCertificate = ../development-key/development.crt;
  enrolment = stagedBuild {
    name = "bunix-secure-boot-enrolment";
    run = ./secure-boot-enrolment.sh;
    buildDepends = [ base.openssl tools.bash tools.coreutils ];
    env = { key = developmentKey; certificate = developmentCertificate; };
  };
  # where it is not a test machine with Secure Boot: nothing
  enrolled = value: if secureBootEnrolment then value else "";
in
stagedBuild {
  name = "bunix-disk";
  run = ./disk.sh;
  # systemd: systemd-repart makes the disk, and systemd-boot goes on it.
  # dosfstools and mtools: the ESP's file system, and what fills it.
  buildDepends = [ base.systemd base.dosfstools base.mtools tools.bash tools.coreutils tools.findutils ]
    # osslsigncode: what systemd-boot is signed with, there
    ++ (if secureBootEnrolment then [ base.osslsigncode ] else []);
  env = {
    update = import ./update.nix { inherit system signature version; };
    # what the update's files are named by
    inherit version;
    partition_architecture = architecture.partitionArchitecture;
    esp_size = espSize;
    usr_slot_size = usrSlotSize;
    usr_verity_size = usrVeritySize;
    secure_boot_enrolment = enrolled enrolment;
    sign_kernel_image = enrolled ../../tools/sign-kernel-image.sh;
    secure_boot_key = enrolled developmentKey;
    secure_boot_certificate = enrolled developmentCertificate;
  };
}
