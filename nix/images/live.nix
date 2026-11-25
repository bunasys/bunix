# bunix-<architecture>-live.img: bunix on a USB stick, to start a machine
# in memory and install bunix from (bunix-install): written whole to the
# stick.  As 0.4.0's: the system it starts runs /usr from the stick, the
# release's own, checked against its hash block by block as it is read;
# its root is in memory (root=tmpfs), and filled as an installed
# system's is at its first boot.  The kernel image is an installed
# system's but for its command line, and the stick a disk with bunix
# installed but for the root partition: started as such a disk is, by
# the initrd (images/initrd.nix), which finds /usr by its hash.
#
#   nix-build /bunix/nix/images/live.nix -A image     (result: bunix-x86-64-live.img)
#   BUNIX_ARCHITECTURE=x86_64 tools/install-test.sh   (installs from it)
#   tools/secure-boot-test.sh                         (and with Secure Boot on)
#
# Its partitions (live.sh):
#
#   ESP          the one a machine boots from:
#     EFI/BOOT/    what firmware starts from a stick: on x86 shim, which
#                  starts systemd-boot beside it (grubx64.efi), signed
#                  with bunix's Secure Boot key; elsewhere systemd-boot.
#                  It starts the one kernel image there.  And MokManager.
#     EFI/Linux/   the live kernel image (live-kernel-image.sh): the
#                  kernel, the initrd, and a command line with /usr's
#                  hash, root=tmpfs, and the mount of this partition at
#                  /run/bunix/medium; signed for Secure Boot on x86
#     install/     this version's kernel image, which bunix-install
#                  installs, and the desktop extension, which it offers
#     bunix.cer    on x86, the certificate of bunix's Secure Boot key,
#                  which a PC's owner enrols in MokManager when its shim
#                  does not know the key yet
#   /usr         this version's (images/update.nix), block for block, by
#                the names a disk's slot A has, but by ids of the stick's
#                own (live-kernel-image.sh says why): what the system on
#                the stick runs, and what bunix-install copies to the disk
#                (it finds them by those names)
#
# So, started from the stick, as root on its console:
#
#   bunix-install /run/bunix/medium/install
#
#   -A liveKernelImage
#                   the live kernel image alone: a test system's signed
#                   for Secure Boot with the development key; a release's
#                   unsigned, for tools/publish.sh to sign.
#   -A image        the stick.
#
#   signature, desktopSignature
#              a release's: the signatures of the system's hash and of
#              the desktop extension's (tools/publish.sh makes both),
#              as images/update.nix and images/desktop.nix take them.
#   signedKernelImage, signedLiveKernelImage, secureBootLoader
#              x86, a release's: this version's kernel image, the live
#              one (-A liveKernelImage), and systemd-boot
#              (images/system.nix), signed for Secure Boot with bunix's
#              key, which tools/publish.sh signs them with; each is taken
#              if it is this build's own (check-release-signed.sh).
#              Without all of these, a test system's, signed with the
#              development key: it takes updates and Secure Boot images
#              signed with that key, which is not secret, and is never to
#              be published.
#   secureBootEnrolment
#              true for a test machine that is to start with Secure Boot
#              on (tools/secure-boot-test.sh; a test system's): systemd-
#              boot gives the machine's firmware, which has no keys yet,
#              Microsoft's (which shim is signed by) and the development
#              key at the first start (secure-boot-enrolment.sh).  Never
#              for a real machine: its owner's keys are not the stick's
#              to replace.
#   version    the system's, as images/system.nix takes it
{ system ? builtins.currentSystem, signature ? null, desktopSignature ? null
, signedKernelImage ? null, signedLiveKernelImage ? null, secureBootLoader ? null
, secureBootEnrolment ? false, version ? import ../release.nix }:

let
  isX86 = system == "x86_64-linux";
  isRelease = signature != null;
  # all of a release's signatures, or none: a release's system with a test
  # system's anything is no system anybody should install
  hasSecureBootSignatures = signedKernelImage != null && signedLiveKernelImage != null && secureBootLoader != null;
  hasAllSignatures = desktopSignature != null && (hasSecureBootSignatures || !isX86);
  hasNoSignatures = desktopSignature == null && signedKernelImage == null && signedLiveKernelImage == null && secureBootLoader == null;
  signaturesAgree = if isRelease then hasAllSignatures else hasNoSignatures;
  # the firmware's keys replaced: a test machine's, never a real one's
  enrolmentIsForTests = secureBootEnrolment -> (!isRelease && isX86);

  signing = if isRelease then "release" else "development";
  tools = import ../tools.nix { inherit system; };
  base = import ../base.nix { inherit system; };
  boot = import ../boot.nix { inherit system; };
  stagedBuild = import ../stage.nix { inherit system; };
  architecture = import ../architecture.nix system;
  sources = builtins.fromJSON (builtins.readFile ../sources.json);
  fetch = import ../fetch.nix;

  # the system the stick runs is the one installed: of a release, it takes
  # only what the release key signed
  systemImage = import ./system.nix { inherit system signing version secureBootLoader; };
  update = import ./update.nix { inherit system signature version secureBootLoader; };
  developmentKey = ../development-key/development.key;
  developmentCertificate = ../development-key/development.crt;
  # what a test system's files are signed with in their builds
  developmentSigning = {
    sign_kernel_image = ../../tools/sign-kernel-image.sh;
    development_key = developmentKey;
    development_certificate = developmentCertificate;
  };

  # The live kernel image: as an installed system's (images/uki.nix), of
  # the same kernel and initrd, but for its command line.  root=tmpfs: a
  # root in memory, which the initrd gives its top
  # (bunix-root-in-memory.service).  fsck.mode=skip: the check systemd
  # runs before it mounts a partition, which fails on a stick that cannot
  # be written (and then nothing after it starts); a root in memory has
  # nothing to check.  systemd.gpt_auto=0: with a root in memory, systemd
  # takes the disk /usr is on -- the stick -- for the machine's own, and
  # would mount the stick's ESP at /boot, writable (a random seed written
  # to it), beside the mount below; nothing here is found that way.
  # live-kernel-image.sh adds /usr's hash, and the stick's ESP's mount.
  liveKernelImageBuild = stagedBuild {
    name = "bunix-live-kernel-image";
    run = ./live-kernel-image.sh;
    # systemd: ukify, and the stub the image starts with.  python and
    # pefile: ukify is Python, and puts the file together with pefile.
    buildDepends = [ base.systemd tools.python base.python-pefile tools.bash tools.coreutils tools.grep tools.sed ]
      ++ (if isX86 && !isRelease then [ base.osslsigncode ] else []);
    env = developmentSigning // {
      system_image = systemImage;
      initrd = import ./initrd.nix { inherit system; };
      inherit version;
      # x86: the processor's microcode, as in images/uki.nix
      microcode = if isX86 then boot.microcode else "";
      command_line = "root=tmpfs mount.usrfstype=erofs mount.usrflags=ro console=tty0 quiet fsck.mode=skip systemd.gpt_auto=0";
      splash = ../../files/branding/splash.bmp;
      # signed here, with the development key, where it is a test system's
      sign_here = if isX86 && !isRelease then "yes" else "";
    };
  };

  enrolment = stagedBuild {
    name = "bunix-secure-boot-enrolment";
    run = ./secure-boot-enrolment.sh;
    buildDepends = [ base.openssl tools.bash tools.coreutils ];
    env = {
      key = developmentKey;
      certificate = developmentCertificate;
      microsoft_certificate = fetch sources.microsoft-uefi-ca-2011;
    };
  };
in
{
  liveKernelImage = liveKernelImageBuild;

  # (its kernel image alone is built before a release's signatures are
  # made: the checks are the stick's)
  image = assert signaturesAgree; assert enrolmentIsForTests; stagedBuild {
    name = "bunix-live";
    run = ./live.sh;
    # systemd: systemd-repart, which makes the image.  dosfstools and
    # mtools: the ESP's file system, and what fills it.  osslsigncode:
    # what a release's signatures are checked with.
    # util-linux: sfdisk, which says where the ESP is in the image
    buildDepends = [ base.systemd base.dosfstools base.mtools base.util-linux
                     tools.bash tools.coreutils tools.findutils tools.grep tools.sed ]
      ++ (if isX86 then [ base.osslsigncode ] else []);
    env = developmentSigning // {
      # what a release's signed kernel images are checked with (and it
      # signs with the development key, above, to compare)
      check_release_signed = ./check-release-signed.sh;
      release_certificate = ../../keys/secureboot.crt;
      inherit update version;
      # x86: shim, and systemd-boot signed, which it starts: the same as
      # the system's /usr has, for its installer
      shim = if isX86 then boot.shim else "";
      signed_loader = if isX86 then import ./signed-loader.nix { inherit system signing secureBootLoader; } else "";
      desktop = (import ./desktop.nix { inherit system version; signature = desktopSignature; }).image;
      partition_architecture = architecture.partitionArchitecture;
      # the live kernel image as built here, and a release's, signed
      built_live_kernel_image = liveKernelImageBuild;
      release_live_kernel_image = if signedLiveKernelImage == null then "" else signedLiveKernelImage;
      release_kernel_image = if signedKernelImage == null then "" else signedKernelImage;
      secure_boot_enrolment = if secureBootEnrolment then enrolment else "";
    };
  };
}
