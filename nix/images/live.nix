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
#   nix-build /bunix/nix/images/live.nix       (result: bunix-x86-64-live.img)
#   BUNIX_ARCHITECTURE=x86_64 tools/install-test.sh   (installs from it)
#
# Its partitions (live.sh):
#
#   ESP          the one a machine boots from:
#     EFI/BOOT/    systemd-boot, which starts the one kernel image there
#     EFI/Linux/   the live kernel image: the kernel, the initrd, and a
#                  command line with /usr's hash, root=tmpfs, and the
#                  mount of this partition at /run/bunix/medium, by an id
#                  of this version's
#     install/     this version's kernel image, which bunix-install
#                  installs, and the desktop extension, which it offers
#   /usr         this version's (images/update.nix), block for block, by
#                the ids and names a disk's slot A has: what the system
#                on the stick runs, and what bunix-install copies to the
#                disk (it finds them by those names)
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
    # the system the stick runs is the one installed: of a release, it
    # takes only what the release key signed
    system_image = import ./system.nix { inherit system signing version; };
    initrd = import ./initrd.nix { inherit system; };
    update = import ./update.nix { inherit system signature version; };
    desktop = (import ./desktop.nix { inherit system version; signature = desktopSignature; }).image;
    inherit version;
    partition_architecture = architecture.partitionArchitecture;
    # x86: the processor's microcode, as in images/uki.nix
    microcode = if system == "x86_64-linux" then boot.microcode else "";
    # As an installed system's (images/uki.nix), but root=tmpfs: a root in
    # memory, which the initrd gives its top (bunix-root-in-memory.service).
    # fsck.mode=skip: the check systemd runs before it mounts a
    # partition, which fails on a stick that cannot be written (and then
    # nothing after it starts); a root in memory has nothing to check.
    # live.sh adds /usr's hash, and the stick's mount.
    command_line = "root=tmpfs mount.usrfstype=erofs mount.usrflags=ro console=tty0 quiet fsck.mode=skip";
    splash = ../../files/branding/splash.bmp;
  };
}
