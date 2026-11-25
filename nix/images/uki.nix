# bunix_<version>.efi: what a machine with bunix on its disk starts, as one
# EFI program (a unified kernel image): the kernel (the one the system
# was built with, which images/system.nix hands on), on x86 the
# processor's microcode (boot.nix), the picture a boot shows,
# images/initrd.nix,
# and the kernel's command line, which has the hash of the one /usr this
# kernel runs (usrhash=).  systemd-boot starts the newest such file on the
# partition the machine boots from.  After elements/system/uki.bst.
#
#   nix-build /bunix/nix/images/uki.nix
#
#   signing, version
#            as images/system.nix takes them: the /usr named is that
#            system's
#
# Signed for Secure Boot on x86, which a PC's firmware has and a Mac's
# EFI (U-Boot) has not: there, whoever can write the partition the image
# is on, or hand words to the machine's firmware, chooses what runs.  A
# test system's image is signed here, by tools/sign-kernel-image.sh with
# the development key, which is not secret (nix/development-key/README):
# the script a release's is signed with, so that a test that starts
# this with Secure Boot on (tools/secure-boot-test.sh) starts what a
# release's signature is.  A release's is not signed by any build: its
# key is in no file, and tools/publish.sh signs what this makes.
#
# No device tree in it: a machine that needs one gets it from what
# started its EFI.
#   secureBootLoader
#            as images/system.nix takes it, for the system it is of
{ system ? builtins.currentSystem, signing ? "development", version ? import ../release.nix
, secureBootLoader ? null }:

let
  tools = import ../tools.nix { inherit system; };
  base = import ../base.nix { inherit system; };
  boot = import ../boot.nix { inherit system; };
  stagedBuild = import ../stage.nix { inherit system; };
  isSignedHere = system == "x86_64-linux" && signing == "development";
in
stagedBuild {
  name = "bunix-uki";
  run = ./uki.sh;
  # systemd: ukify, and the stub the image starts with.  python and
  # pefile: ukify is Python, and puts the file together with pefile.
  buildDepends = [ base.systemd tools.python base.python-pefile tools.bash tools.coreutils tools.grep ]
    # osslsigncode: what the signing script signs with
    ++ (if isSignedHere then [ base.osslsigncode ] else []);
  env = {
    # x86: the processor's microcode, which the stub hands to the kernel
    # before the initrd.  A Mac's processor takes none.
    microcode = if system == "x86_64-linux" then boot.microcode else "";
    # what a test system's image is signed with, and by
    sign_kernel_image = if isSignedHere then ../../tools/sign-kernel-image.sh else "";
    secure_boot_key = if isSignedHere then ../development-key/development.key else "";
    secure_boot_certificate = if isSignedHere then ../development-key/development.crt else "";
    initrd = import ./initrd.nix { inherit system; };
    system_image = import ./system.nix { inherit system signing version secureBootLoader; };
    # root=: the root partition by its name, not by its type, as systemd
    # would find it by itself: another Linux on the same disk has a root
    # partition of that type too, and it is not this system's to mount.
    # rw: it is writable.  mount.usrfstype: said, so that nothing tries to
    # check and repair a file system that is read-only and checked block
    # by block.  console=tty0: the console is the screen; a machine
    # without one adds its own console after it, as its firmware hands
    # words over (tools/boot-vm.sh).
    # quiet: the kernel writes only what is worse than an error
    # (boot/linux/), and systemd only of a unit that failed, or of one
    # that keeps the boot waiting.  The picture below stays on the
    # screen until the first text is written: the login prompt, or one
    # of those.
    command_line = "root=PARTLABEL=bunix-root rw mount.usrfstype=erofs mount.usrflags=ro console=tty0 quiet";
    # What is on the screen from before the kernel starts: bunix's mark,
    # which systemd's stub draws in the middle of it, unscaled.
    # tools/render-branding.sh makes it.  base.boot-picture draws the
    # same file again, when a GPU's driver takes the screen.
    splash = ../../files/branding/splash.bmp;
  };
}
