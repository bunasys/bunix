# The first bunix system that boots, as an initramfs: an archive the kernel
# unpacks into memory and runs /init from.
#
#   nix-build /bunix/nix/images/initramfs.nix     (result: initramfs.cpio.gz)
#   tools/boot-vm.sh                              (on the Mac: builds and boots it)
#
# It is the usr/ and etc/ of `contents`, and of everything they need to
# run, laid over each other as one root: /usr/bin/bash, /usr/lib/<triplet>/
# libc.so.6.  There is no /nix in it.
{ system ? builtins.currentSystem }:

let
  toolchain = import ../toolchain.nix { inherit system; };
  tools = import ../tools.nix { inherit system; };
  base = import ../base.nix { inherit system; };
  boot = import ../boot.nix { inherit system; };
  stagedBuild = import ../stage.nix { inherit system; };
in
stagedBuild {
  name = "bunix-initramfs";
  run = ./initramfs.sh;

  # What the system has.  gccLibraries because glibc loads libgcc_s.so.1
  # when a thread is cancelled or exits early, in a C program too, and
  # because most programs built elsewhere ask for it or for libstdc++.so.6;
  # glibc cannot depend on it, it is built from glibc.
  contents = [
    tools.bash tools.coreutils base.util-linux toolchain.gccLibraries
    # what a person at its shell expects to find
    tools.sed tools.grep tools.gawk tools.findutils tools.diffutils tools.tar tools.gzip
    base.procps-ng base.iputils
    # the network, and a way in over it
    base.iproute2 base.dhcpcd base.openssh base.rex
    # Wi-Fi, without the chip's firmware (boot/linux/aarch64.config)
    base.iwd base.wireless-regdb
  ];

  # What packs it.  gen_init_cpio comes with the kernel.
  buildDepends = [ boot.linux tools.bash tools.coreutils tools.findutils tools.grep tools.gzip ];
  env = { init = ./init.sh; usb_link = ./usb-link.sh; };
}
