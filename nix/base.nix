# Packages of a bunix system, after elements/base/: each is built with the
# system's own compiler and tools (tools.nix), and nothing of the bootstrap.
# The exceptions are under "Programs built elsewhere".
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
  fetch = import ./fetch.nix;
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

  # Zstandard compression: the zstd command and libzstd.  zstdgrep and
  # zstdless are shell scripts.
  zstd = mkSystemPackage {
    name = "zstd";
    source = sources.zstd;
    script = ./base/zstd.sh;
    depends = [ glibc tools.bash ];
  };

  # The XML parser dbus-daemon reads its policy files with
  expat = mkSystemPackage {
    name = "expat";
    source = sources.expat;
    script = ./autotools.sh;
    depends = [ glibc ];
    env = { configure_arguments = "--disable-static --without-docbook --without-examples --without-tests"; };
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

  # D-Bus, the system bus: iwd is spoken to over it, and does not start
  # without it.  Without the parts for systemd, which is not here yet.
  dbus = mkSystemPackage {
    name = "dbus";
    source = sources.dbus;
    script = ./base/dbus.sh;
    depends = [ glibc expat ];
    buildDepends = [ meson ninja pkgconf ];
  };

  # iwd, the wireless daemon: scans, authenticates and keeps the link up,
  # and leaves addresses to whatever hands them out.  iwctl is its client.
  # The chip's firmware is not a package (boot/linux/aarch64.config).
  iwd = mkSystemPackage {
    name = "iwd";
    source = sources.iwd;
    script = ./base/iwd.sh;
    depends = [ glibc readline ncurses dbus ];
    buildDepends = [ pkgconf ];
  };

  # The wireless regulatory database: which channels and transmit powers
  # are legal where.  The kernel loads it as it loads firmware, and checks
  # its signature against keys built into it.
  wireless-regdb = mkSystemPackage {
    name = "wireless-regdb";
    source = sources.wireless-regdb;
    script = ./base/wireless-regdb.sh;
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

  # Rust: rustc, its standard library, cargo, rustfmt, and the standard
  # library's source, which the kernel compiles for itself; five archives
  # of one version (sources.json).  As the Rust project publishes them, in
  # /usr/lib/rust, where rustc finds its own libraries beside itself;
  # elements/bootstrap/rust.bst builds the same version from source, with
  # this as its seed.
  #
  # rustfmt: bindgen formats what it writes with it when it is there, and
  # the kernel's test of bindgen looks for text formatted that way.
  rust = mkSystemPackage {
    name = "rust";
    source = sources."rustc-${system}";
    script = ./base/rust.sh;
    # gcc: rustc links what it compiles with it.  zlib: the LLVM inside
    # rustc reads compressed sections with it.
    depends = [ glibc toolchain.gccLibraries toolchain.gcc zlib ];
    builtElsewhere = true;
    env = {
      rust_std = fetch sources."rust-std-${system}";
      cargo = fetch sources."cargo-${system}";
      rustfmt = fetch sources."rustfmt-${system}";
      rust_src = fetch sources.rust-src;
    };
  };

  # Rust's core libraries for a 64-bit Arm processor with no operating
  # system under the program, and no use of its floating-point registers
  # (the softfloat target): what a boot loader is compiled against
  # (boot.nix).  The same archive whatever the builder is, of rust's
  # version; it adds a directory to rust's.
  rust-std-aarch64-none = mkSystemPackage {
    name = "rust-std-aarch64-none";
    source = sources.rust-std-aarch64-none;
    script = ./base/rust-std-aarch64-none.sh;
    depends = [ rust ];
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

  # The build tool CMake generates for
  ninja = mkSystemPackage {
    name = "ninja";
    source = sources.ninja;
    script = ./base/ninja.sh;
    depends = [ glibc toolchain.gccLibraries ];
  };

  # Python's zlib module.  The Python that builds run (tools.nix) is built
  # before any library, and has only the modules that need none; one that
  # needs a library is a package like this, laid over it.  From Python's
  # own source.
  python-zlib = mkSystemPackage {
    name = "python-zlib";
    source = sources.python;
    script = ./base/python-zlib.sh;
    depends = [ glibc tools.python zlib ];
  };

  # The build system dbus uses, and systemd will.  It is Python, and ninja
  # does the building.  python-zlib: it reads gzip when it starts.
  meson = mkSystemPackage {
    name = "meson";
    source = sources.meson;
    script = ./base/meson.sh;
    depends = [ tools.python python-zlib ninja ];
  };

  # The build system LLVM uses
  cmake = mkSystemPackage {
    name = "cmake";
    source = sources.cmake;
    script = ./base/cmake.sh;
    depends = [ glibc toolchain.gccLibraries ];
  };

  # LLVM, clang and lld: the compiler and linker the kernel is built with,
  # on both architectures, and the libclang that bindgen reads C headers
  # with.  Its major version is that of the LLVM inside the Rust compiler,
  # as the kernel's build expects.  clang takes the C library, the
  # start-up files and libgcc from where gcc has them; a build that links
  # programs with it has gcc too.
  llvm = mkSystemPackage {
    name = "llvm";
    source = sources.llvm;
    script = ./base/llvm.sh;
    depends = [ glibc toolchain.gccLibraries zlib zstd ];
    buildDepends = [ cmake ninja ];
  };

  # Makes Rust declarations from C headers; the kernel's Rust code calls
  # its C code through them.  It reads the headers with LLVM's libclang,
  # which it loads when it runs.  The patches are Aurora Silicon's, as they
  # are in tools/aurora-bindgen/ of their kernel (sources.json has the
  # commit): two kinds of C struct whose layout bindgen 0.73.2 gets wrong.
  bindgen = mkSystemPackage {
    name = "bindgen";
    source = sources.bindgen;
    script = ./base/bindgen.sh;
    depends = [ glibc toolchain.gccLibraries llvm ];
    buildDepends = [ rust ];
    env = {
      patches = [
        ../files/bindgen/0001-empty-alignment.patch
        ../files/bindgen/0002-anonymous-tag-members.patch
      ];
      # The crates bindgen is made of, each pinned; cargo downloads
      # nothing in a build.  The list is bindgen's Cargo.lock, as the
      # `cargo` source of elements/base/bindgen.bst has it.
      crates = map (crate: fetch {
        url = "https://static.crates.io/crates/${crate.name}/${crate.name}-${crate.version}.crate";
        inherit (crate) sha256;
      }) (builtins.fromJSON (builtins.readFile ./base/bindgen-crates.json));
    };
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
  inherit readline zlib bzip2 zstd openssl libmnl expat;
  inherit util-linux iproute2 dhcpcd openssh dbus iwd wireless-regdb rex rust rust-std-aarch64-none;
  inherit pkgconf flex bc perl ninja python-zlib meson cmake llvm bindgen;
}
