# bunix with systemd as its init system, as an initramfs: an archive the
# kernel unpacks into memory and runs /init from, which is systemd.
#
#   nix-build /bunix/nix/images/system.nix     (result: initramfs.cpio.gz)
#
# It is the usr/ and etc/ of `contents`, and of everything they need to
# run, with bunix's configuration over them: files/rootfs's where the
# system on x86 has the same (the list is in system.sh), images/system/
# where this one differs yet.
# Accounts are made of what the packages ask for, and units enabled as
# the preset says, when the image is made (system.sh).
{ system ? builtins.currentSystem }:

let
  toolchain = import ../toolchain.nix { inherit system; };
  tools = import ../tools.nix { inherit system; };
  base = import ../base.nix { inherit system; };
  boot = import ../boot.nix { inherit system; };
  stagedBuild = import ../stage.nix { inherit system; };
in
stagedBuild {
  name = "bunix-system";
  run = ./system.sh;

  # What the system has.  gccLibraries because glibc loads libgcc_s.so.1
  # when a thread is cancelled or exits early, in a C program too, and
  # because most programs built elsewhere ask for it or for libstdc++.so.6;
  # glibc cannot depend on it, it is built from glibc.
  contents = [
    base.systemd tools.bash tools.coreutils base.util-linux toolchain.gccLibraries
    # what a person at its shell expects to find
    tools.sed tools.grep tools.gawk tools.findutils tools.diffutils tools.tar tools.gzip
    base.procps-ng base.iputils base.iproute2 base.kmod
    # a disk: systemd checks and makes file systems with these
    base.e2fsprogs base.dosfstools
    # the network, and a way in over it
    base.openssh base.rex
    # Wi-Fi, without the chip's firmware (boot/linux/aarch64.config)
    base.dbus base.iwd base.wireless-regdb
  ];

  # What makes it.  systemd: its own tools make the accounts, enable the
  # units and compile the hardware database, on the tree that is to be the
  # image.  gen_init_cpio comes with the kernel.
  buildDepends = [ boot.linux base.systemd tools.bash tools.coreutils tools.findutils tools.grep tools.sed tools.gzip ];
  env = {
    bunix_files = ./system;
    usb_link = ./usb-link.sh;
    shared_files = ../../files/rootfs;
  };
}
