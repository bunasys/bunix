# Packages of a bunix system, after elements/base/: each is built with the
# system's own compiler and tools (tools.nix), and nothing of the bootstrap.
# The exceptions are at the end, under "Programs built elsewhere".
#
#   nix-build /bunix/nix/base.nix -A util-linux
#
# Porting elements/base/x.bst:
#   description        -> a comment above the entry
#   sources            -> sources.json "x"; a patch -> env.patches, applied
#                         by the script
#   depends            -> depends, plus glibc for a program or library, and
#                         bash for a script in /usr/bin
#   build-depends      -> buildDepends, without bootstrap/build-env.bst
#   kind: autotools with only conf-local
#                      -> script = ./autotools.sh; env.configure_arguments
#   make-args, install-commands (>), kind: manual, or an argument with a
#   space in it        -> base/x.sh: autotools.sh's four lines, and the rest
#   overlap-whitelist  -> nothing: two packages with one file is an error
# and a comment for every flag that is not the element's.
{ system ? builtins.currentSystem }:

let
  toolchain = import ./toolchain.nix { inherit system; };
  tools = import ./tools.nix { inherit system; };
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  inherit (toolchain) glibc;
  inherit (tools) ncurses;

  mkSystemPackage = import ./system-package.nix {
    inherit system;
    inherit (tools) buildEnvironment;
    defaultEnv = tools.compilerFlags;
  };

  # ---- Libraries -----------------------------------------------------------

  # GNU readline: line editing for the programs that link it (not bash,
  # which has its own copy).  The patches are upstream's fixes since 8.3,
  # as they publish them; 002 fixes a crash in iwctl.
  readline = mkSystemPackage {
    name = "readline";
    source = sources.readline;
    script = ./base/readline.sh;
    depends = [ glibc ncurses ];
    env = {
      patches = [
        ../files/readline/readline83-001
        ../files/readline/readline83-002
        ../files/readline/readline83-003
        ../files/readline/readline83-004
        ../files/readline/readline83-005
        ../files/readline/readline83-006
      ];
    };
  };

  # Compression, as a library: OpenSSH's, and later most things'.
  zlib = mkSystemPackage {
    name = "zlib";
    source = sources.zlib;
    script = ./base/zlib.sh;
    depends = [ glibc ];
  };

  # bzip2 and libbz2.  tar runs bzip2 to unpack a .tar.bz2 source.
  bzip2 = mkSystemPackage {
    name = "bzip2";
    source = sources.bzip2;
    script = ./base/bzip2.sh;
    depends = [ glibc ];
  };

  # TLS and cryptography: libssl, libcrypto and the openssl command.  Its
  # build is a perl program.
  openssl = mkSystemPackage {
    name = "openssl";
    source = sources.openssl;
    script = ./base/openssl.sh;
    depends = [ glibc ];
    buildDepends = [ perl ];
  };

  # Netlink messages, the kernel's protocol for network configuration;
  # iproute2 speaks it through this.
  libmnl = mkSystemPackage {
    name = "libmnl";
    source = sources.libmnl;
    script = ./autotools.sh;
    depends = [ glibc ];
    buildDepends = [ bzip2 ];
    env = { configure_arguments = "--disable-static"; };
  };

  # ---- Commands --------------------------------------------------------------

  # mount, and the rest of what talks to the kernel about disks, terminals
  # and processes
  util-linux = mkSystemPackage {
    name = "util-linux";
    source = sources.util-linux;
    script = ./base/util-linux.sh;
    depends = [ glibc ncurses readline ];
    buildDepends = [ pkgconf ];
  };

  # ip, ss and bridge: network interfaces, addresses and routes
  iproute2 = mkSystemPackage {
    name = "iproute2";
    source = sources.iproute2;
    script = ./base/iproute2.sh;
    depends = [ glibc libmnl ];
    buildDepends = [ pkgconf ];
  };

  # A DHCP client: asks the network for an address, a route and name
  # servers.  Not an element of elements/base/, where systemd-networkd
  # does this; it is here until systemd is.  Its hooks are shell scripts
  # that run sed and coreutils.
  dhcpcd = mkSystemPackage {
    name = "dhcpcd";
    source = sources.dhcpcd;
    script = ./base/dhcpcd.sh;
    depends = [ glibc tools.bash tools.coreutils tools.sed ];
  };

  # OpenSSH: ssh, scp, sftp, ssh-keygen and ssh-agent, and sshd: keys
  # only, no passwords (files/rootfs/etc/ssh/sshd_config).
  openssh = mkSystemPackage {
    name = "openssh";
    source = sources.openssh;
    script = ./base/openssh.sh;
    depends = [ glibc openssl zlib ];
    env = { sshd_config = ../files/rootfs/etc/ssh/sshd_config; };
  };

  # ---- Programs built elsewhere ----------------------------------------------

  # Rex (superlogical.com/rex): makes this machine a remote host for the
  # rex command and Rex for Mac, over SSH.  Published as a program, not as
  # source, one archive for each architecture (sources.json).
  rex = mkSystemPackage {
    name = "rex";
    source = sources."rex-${system}";
    script = ./base/rex.sh;
    depends = [ glibc ];
    # Rex's builders used Nix: it names four paths of their store, where
    # its Go runtime would look for time zones and MIME types last.
    builtElsewhere = true;
  };

  # ---- Build tools -----------------------------------------------------------

  # pkg-config: tells a build the flags to compile and link against a
  # library, from the .pc file the library installed
  pkgconf = mkSystemPackage {
    name = "pkgconf";
    source = sources.pkgconf;
    script = ./base/pkgconf.sh;
    depends = [ glibc ];
  };

  # Generates scanners; the kernel's configuration tool is built with one.
  # flex runs m4.
  flex = mkSystemPackage {
    name = "flex";
    source = sources.flex;
    script = ./autotools.sh;
    depends = [ glibc tools.m4 ];
    env = { configure_arguments = "--disable-static --disable-nls"; };
  };

  # Gavin Howard's bc: GNU's needs ed and texinfo to build.  The kernel's
  # build computes with it.
  bc = mkSystemPackage {
    name = "bc";
    source = sources.bc;
    script = ./base/bc.sh;
    depends = [ glibc ];
  };

  # The kernel generates some of its assembly with perl scripts, and
  # OpenSSL's build is one.
  perl = mkSystemPackage {
    name = "perl";
    source = sources.perl;
    script = ./base/perl.sh;
    depends = [ glibc ];
  };
in
{
  inherit readline zlib bzip2 openssl libmnl;
  inherit util-linux iproute2 dhcpcd openssh rex;
  inherit pkgconf flex bc perl;
}
