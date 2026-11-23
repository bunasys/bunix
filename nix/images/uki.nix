# bunix_<version>.efi: what a machine with bunix on its disk starts, as one
# EFI program (a unified kernel image): the kernel (the one the system
# was built with, which images/system.nix hands on), images/initrd.nix,
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
# Not signed: what would check it is Secure Boot, which a Mac's EFI
# (U-Boot) does not have.  So whoever can write the partition it is on,
# or hand words to the machine's firmware, chooses what runs; nothing
# here stands against that yet.
#
# No device tree in it: a machine that needs one gets it from what
# started its EFI.
{ system ? builtins.currentSystem, signing ? "development", version ? import ../release.nix }:

let
  tools = import ../tools.nix { inherit system; };
  base = import ../base.nix { inherit system; };
  stagedBuild = import ../stage.nix { inherit system; };
in
stagedBuild {
  name = "bunix-uki";
  run = ./uki.sh;
  # systemd: ukify, and the stub the image starts with.  python and
  # pefile: ukify is Python, and puts the file together with pefile.
  buildDepends = [ base.systemd tools.python base.python-pefile tools.bash tools.coreutils ];
  env = {
    initrd = import ./initrd.nix { inherit system; };
    system_image = import ./system.nix { inherit system signing version; };
    # root=: the root partition by its name, not by its type, as systemd
    # would find it by itself: another Linux on the same disk has a root
    # partition of that type too, and it is not this system's to mount.
    # rw: it is writable.  mount.usrfstype: said, so that nothing tries to
    # check and repair a file system that is read-only and checked block
    # by block.  console=tty0: the boot's messages on the screen; a
    # machine without one adds its own console after it, as its firmware
    # hands words over (tools/boot-vm.sh).
    command_line = "root=PARTLABEL=bunix-root rw mount.usrfstype=erofs mount.usrflags=ro console=tty0";
  };
}
