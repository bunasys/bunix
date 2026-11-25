# bunix-<architecture>-live.img: bunix on a USB stick, to start a machine
# in memory and install bunix from (bunix-install): written whole to the
# stick.  After 0.4.0's live image, without its /usr from the stick: the
# system the stick starts is all in memory, as the one tools/boot-mac.sh
# starts on a Mac.  About 575 MB of it unpacked, from 380 MB packed,
# both in memory while it unpacks: a machine with 2 GB has room
# (tools/install-test.sh's has 4).
#
#   nix-build /bunix/nix/images/live.nix       (result: bunix-x86-64-live.img)
#   BUNIX_ARCHITECTURE=x86_64 tools/install-test.sh   (installs from it)
#
# One partition, the one a machine boots from (live.sh):
#
#   EFI/BOOT/      systemd-boot, which starts the one kernel image there
#   EFI/Linux/     the live kernel image: the kernel, and the whole system
#                  as its initramfs, and a command line that mounts this
#                  partition at /run/bunix/medium, by an id of this
#                  version's (live.sh)
#   install/       the files of this version that bunix-install installs
#                  (images/update.nix), and the desktop extension, which
#                  it offers
#
# So, started from the stick, as root on its console:
#
#   bunix-install /run/bunix/medium/install
#
# Not yet: Secure Boot.  Nothing on the stick is signed for it, and a
# machine starts it, and the bunix it installs, with Secure Boot off.
#
#   signature, desktopSignature
#              a release's: the signatures of the system's hash and of
#              the desktop extension's (tools/publish.sh makes both),
#              as images/update.nix and images/desktop.nix take them.
#              Without them, a test system's, signed with the
#              development key: it takes updates signed with that key,
#              which is not secret, and is never to be published.
#   version    the system's, as images/system.nix takes it
{ system ? builtins.currentSystem, signature ? null, desktopSignature ? null
, version ? import ../release.nix }:

# Both, or neither: a release's system with a test system's desktop, or
# the other way round, is no system anybody should install
assert (signature == null) == (desktopSignature == null);

let
  signing = if signature == null then "development" else "release";
  tools = import ../tools.nix { inherit system; };
  base = import ../base.nix { inherit system; };
  boot = import ../boot.nix { inherit system; };
  stagedBuild = import ../stage.nix { inherit system; };
  architecture = import ../architecture.nix system;
in
stagedBuild {
  name = "bunix-live";
  run = ./live.sh;
  # systemd: ukify, the stub the kernel image starts with, systemd-boot,
  # and systemd-repart, which makes the image.  python and pefile: ukify
  # is Python, and puts the file together with pefile.  dosfstools and
  # mtools: the partition's file system, and what fills it.
  buildDepends = [ base.systemd tools.python base.python-pefile base.dosfstools base.mtools
                   tools.bash tools.coreutils tools.findutils tools.grep tools.sed ];
  env = {
    # the system in memory is the one installed: of a release, it takes
    # only what the release key signed
    system_image = import ./system.nix { inherit system signing version; };
    update = import ./update.nix { inherit system signature version; };
    desktop = (import ./desktop.nix { inherit system version; signature = desktopSignature; }).image;
    inherit version;
    partition_architecture = architecture.partitionArchitecture;
    # x86: the processor's microcode, as in images/uki.nix
    microcode = if system == "x86_64-linux" then boot.microcode else "";
    # console=tty0 quiet: as an installed system's (images/uki.nix).
    # fsck.mode=skip: the check systemd runs before it mounts a
    # partition, which fails on a stick that cannot be written (and then
    # nothing after it starts); a system in memory has no file system of
    # its own to check.  live.sh adds the stick's mount.
    command_line = "console=tty0 quiet fsck.mode=skip";
    splash = ../../files/branding/splash.bmp;
  };
}
