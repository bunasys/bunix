# bunix-<architecture>-live.img: bunix on a USB stick, to start a machine
# in memory and install bunix from (bunix-install): written whole to the
# stick.  After 0.4.0's elements/system/live.bst, without its /usr from
# the stick: the system the stick starts is all in memory, as the one
# tools/boot-mac.sh starts on a Mac.
#
#   nix-build /bunix/nix/images/live.nix       (result: bunix-x86-64-live.img)
#   BUNIX_ARCHITECTURE=x86_64 tools/install-test.sh   (installs from it)
#
# One partition, the one a machine boots from (live.sh):
#
#   EFI/BOOT/      systemd-boot, which starts the one kernel image there
#   EFI/Linux/     the live kernel image: the kernel, and the whole system
#                  as its initramfs, and a command line that mounts this
#                  partition at /run/bunix/medium
#   install/       the files of this version that bunix-install installs
#                  (images/update.nix), and the desktop extension, which
#                  it offers
#
# So, started from the stick, as root on its console:
#
#   bunix-install /run/bunix/medium/install
#
# Not yet: Secure Boot (a machine starts it with Secure Boot off), and a
# machine whose ESP has another system's loader in EFI/BOOT, as a PC
# with Windows has (bunix-install refuses that ESP).  A test system's,
# signed with the development key; a release's is to come.
#
#   version    the system's, as images/system.nix takes it
{ system ? builtins.currentSystem, version ? import ../release.nix }:

let
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
                   tools.bash tools.coreutils tools.findutils tools.grep ];
  env = {
    system_image = import ./system.nix { inherit system version; };
    update = import ./update.nix { inherit system version; };
    desktop = (import ./desktop.nix { inherit system version; }).image;
    inherit version;
    partition_architecture = architecture.partitionArchitecture;
    # x86: the processor's microcode, as in images/uki.nix
    microcode = if system == "x86_64-linux" then boot.microcode else "";
    # console=tty0 quiet: as an installed system's (images/uki.nix).
    # systemd.mount-extra: the stick's partition, by the name live.sh
    # gives it, read-only where bunix-install is told to look; systemd
    # mounts it as it would a line of /etc/fstab, which a system in
    # memory has none of.  nofail: without the stick (pulled out, or not
    # found) the system starts all the same, and bunix-install says it
    # has no files.  fsck.mode=skip: the check systemd runs before it
    # mounts a partition, which fails on a stick that cannot be written
    # (and then nothing after it starts); a system in memory has no file
    # system of its own to check.
    command_line = "console=tty0 quiet fsck.mode=skip systemd.mount-extra=PARTLABEL=bunix-live:/run/bunix/medium:vfat:ro,nofail";
    splash = ../../files/branding/splash.bmp;
  };
}
