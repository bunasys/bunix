# bunix with systemd as its init system, as an initramfs: an archive the
# kernel unpacks into memory and runs /init from, which is systemd.
#
#   nix-build /bunix/nix/images/system.nix
#
# The result: initramfs.cpio.gz, the whole system for a machine's memory;
# and, of the same tree, usr-partition/: /usr as the images of a
# partition, for a machine's disk (image.sh).  One build for both, at the
# cost of each being made when only the other is wanted: the tree they
# are made of is not kept.  And usr-paths, the list of what /usr has, for
# what makes an extension (images/extension.nix).
#
# It is the usr/ and etc/ of `contents`, and of everything they need to
# run, with bunix's configuration over them: files/rootfs's where the
# system on x86 has the same (the list is below), images/system/ where
# this one differs yet.
# Accounts are made of what the packages ask for, and units enabled as
# the preset says, when the image is made (image.sh).
#
#   signing  whose signatures on an image's hash this system takes.
#            "development" (the default): the development key's, which is
#            not secret (nix/development-key/README), as well as bunix's;
#            and the system says so of itself (VARIANT_ID).  For test
#            builds.
#            "release": bunix's only.
#   version  what the system says its version is, and what its update
#            files are named by: an update is a system with a later one.
#            The release's (nix/release.nix), unless a test asks for
#            another, to have something to update to.
{ system ? builtins.currentSystem, signing ? "development", version ? import ../release.nix }:

assert signing == "development" || signing == "release";
# Digits and dots: the version is part of the names of partitions and of
# files, where "+", "_" and "-" say where it ends (boot counting, and the
# patterns of system/usr/lib/sysupdate.d).
assert builtins.match "[0-9]+([.][0-9]+)*" version != null;

let
  toolchain = import ../toolchain.nix { inherit system; };
  tools = import ../tools.nix { inherit system; };
  base = import ../base.nix { inherit system; };
  boot = import ../boot.nix { inherit system; };
  stagedBuild = import ../stage.nix { inherit system; };
in
stagedBuild {
  name = "bunix-system";
  run = ./image.sh;

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
    base.openssh
    # accounts: what checks who logs in and opens their session (PAM),
    # the console's login prompt, and the tools that make and change users
    base.linux-pam base.util-linux-login base.shadow
    # the shell a user may have in place of bash
    base.fish
    # a user's way up: run0 asks polkit, which asks a member of wheel
    # for their own password
    base.polkit
    # Wi-Fi, without the chip's firmware (boot/linux/aarch64.config)
    base.dbus base.iwd base.wireless-regdb
    # for a system on a disk: udev told of the device /usr is checked
    # through
    base.dm-udev-rules
    # and what checks the signature of an update's list of files, for
    # the gpg below
    base.sqv
  ]
  # and what a Mac's own boot loader loads from the ESP, for the
  # installer to put there (x86 has no such Mac to start)
  ++ (if system == "aarch64-linux" then [ boot.mac-stage2 ] else []);

  # What makes it.  systemd: its own tools make the accounts, enable the
  # units and compile the hardware database, on the tree that is to be the
  # image.  gen_init_cpio comes with the kernel.
  # erofs-utils: the file system of /usr's image.
  buildDepends = [ boot.linux base.systemd base.erofs-utils tools.bash tools.coreutils tools.tar tools.findutils tools.grep tools.sed tools.gzip ];
  env = {
    bunix_files = ./system;
    shared_files = ../../files/rootfs;
    # What is not listed is not here.  machine-id is empty: the machine
    # has a new id at every boot, unless its command line gives it one,
    # and systemd does not take the boot for a first one.
    same_as_x86 = [
      "etc/hostname" "etc/hosts" "etc/nsswitch.conf" "etc/shells" "etc/machine-id"
      "etc/os-release" "etc/resolv.conf" "etc/iwd/main.conf"
      "usr/lib/os-release"
      "usr/lib/systemd/network/20-wired.network"
      "usr/lib/systemd/network/25-wireless.network"
      "usr/lib/systemd/resolved.conf.d/bunix.conf"
      "usr/lib/systemd/timesyncd.conf.d/bunix.conf"
      "usr/lib/systemd/system/console-shell@.service"
      "usr/lib/systemd/system/systemd-sysusers.service.d/bunix.conf"
      # PAM's rules, by the package whose programs ask.  A program with
      # none of its own gets "other", and is refused.
      # every program's: how a password is checked and kept, what a login is
      "usr/lib/pam.d/system-auth" "usr/lib/pam.d/system-login" "usr/lib/pam.d/other"
      # util-linux-login's
      "usr/lib/pam.d/login" "usr/lib/pam.d/runuser" "usr/lib/pam.d/runuser-l"
      # openssh's, and what its rules run to check the account: without
      # that script no key logs in
      "usr/lib/pam.d/sshd" "usr/lib/bunix/ssh-account-locked"
      # shadow's.  (x86 has rules for useradd and its kin as well, which
      # those tools never open.)
      "usr/lib/pam.d/passwd" "usr/lib/pam.d/chpasswd"
      # whose signature on a list of update files is taken: the release
      # key's (docs/updates.md)
      "usr/lib/systemd/import-pubring.pgp"
      # the gpg systemd runs to check it, which is not GnuPG: a script
      # that hands the check to sqv
      "usr/bin/gpg"
    ];
    # passwd: a user changes their own password, in /etc/shadow, which
    # only root may write (PAM asks for the old one first).  As
    # elements/system/usr.bst.
    # chsh: the same for their shell, in /etc/passwd (system/usr/lib/pam.d/chsh).
    set_user_id = [ "usr/bin/passwd" "usr/bin/chsh" ];
    inherit version;
    usr_partition = "yes";
    certificates = [ ../../keys/verity.crt ]
      ++ (if signing == "development" then [ ../development-key/development.crt ] else []);
  } // (if signing == "development" then { variant = "development"; } else {});
}
