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
#   kind: meson with only meson-local
#                      -> script = ./meson.sh; env.meson_arguments
#   kind: cmake with only cmake-local
#                      -> script = ./cmake.sh; env.cmake_arguments
#   make-args, install-commands (>), kind: manual, or an argument with a
#   space in it        -> base/x.sh: the lines of autotools.sh or meson.sh,
#                         and the rest
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

  # POSIX capabilities: a part of root's rights, given or given up.
  # systemd requires it.
  libcap = mkSystemPackage {
    name = "libcap";
    source = sources.libcap;
    script = ./base/libcap.sh;
    depends = [ glibc ];
  };

  # crypt(), which glibc no longer has: password hashing.  perl generates
  # its tables.  --disable-werror: glibc's strchr returns const for a
  # const string, which this source's build with -Werror does not expect
  # yet.
  libxcrypt = mkSystemPackage {
    name = "libxcrypt";
    source = sources.libxcrypt;
    script = ./autotools.sh;
    depends = [ glibc ];
    buildDepends = [ pkgconf perl ];
    env = { configure_arguments = "--disable-static --disable-werror --enable-hashes=strong,glibc --disable-obsolete-api --disable-failure-tokens"; };
  };

  # Extended attributes of files: libattr, which libacl is built with, and
  # getfattr and setfattr.
  attr = mkSystemPackage {
    name = "attr";
    source = sources.attr;
    script = ./autotools.sh;
    depends = [ glibc ];
    env = { configure_arguments = "--disable-static --disable-nls"; };
  };

  # Access control lists, and getfacl and setfacl.  systemd gives the
  # person at the machine its sound, cameras and keys with them, and takes
  # them back.
  acl = mkSystemPackage {
    name = "acl";
    source = sources.acl;
    script = ./autotools.sh;
    depends = [ glibc attr ];
    env = { configure_arguments = "--disable-static --disable-nls"; };
  };

  # Command-line parsing; cryptsetup's configure requires it.
  popt = mkSystemPackage {
    name = "popt";
    source = sources.popt;
    script = ./autotools.sh;
    depends = [ glibc ];
    env = { configure_arguments = "--disable-static --disable-nls"; };
  };

  # The JSON library cryptsetup keeps its metadata in.
  json-c = mkSystemPackage {
    name = "json-c";
    source = sources.json-c;
    script = ./cmake.sh;
    depends = [ glibc ];
    buildDepends = [ cmake ninja ];
    env = { cmake_arguments = "-DBUILD_STATIC_LIBS=OFF -DBUILD_TESTING=OFF -DDISABLE_WERROR=ON"; };
  };

  # libdevmapper and dmsetup, from LVM2: cryptsetup sets up dm-verity
  # through this library.
  device-mapper = mkSystemPackage {
    name = "device-mapper";
    source = sources.device-mapper;
    script = ./base/device-mapper.sh;
    depends = [ glibc ];
    buildDepends = [ pkgconf ];
  };

  # The device mapper's udev rules, from LVM2: they name /dev/mapper/*
  # devices and tell systemd when one is ready.  Without them systemd
  # waits for ever for /dev/mapper/usr, the /usr of a system on a disk.
  # A package of its own, of device-mapper's source, so that the rules can
  # change without rebuilding everything that links libdevmapper, systemd
  # among it.  The rules run dmsetup.
  dm-udev-rules = mkSystemPackage {
    name = "dm-udev-rules";
    source = sources.device-mapper;
    script = ./base/dm-udev-rules.sh;
    depends = [ device-mapper ];
    buildDepends = [ pkgconf ];
  };

  # Fast compression: mkfs.erofs compresses a system's /usr with it, which
  # is read back several times faster than LZMA.
  lz4 = mkSystemPackage {
    name = "lz4";
    source = sources.lz4;
    script = ./base/lz4.sh;
    depends = [ glibc ];
  };

  # Mozilla's certificates of the authorities that vouch for servers, as
  # the curl project extracts them: what curl and OpenSSL check a server
  # against.
  ca-certificates = mkSystemPackage {
    name = "ca-certificates";
    source = sources.ca-certificates;
    script = ./base/ca-certificates.sh;
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

  # libcryptsetup, which systemd sets up dm-verity with for /usr and the
  # extension images, and cryptsetup and veritysetup, to open and check
  # such volumes by hand.  Without integritysetup.  --disable-udev: libudev
  # is systemd's, which is built against this.
  cryptsetup = mkSystemPackage {
    name = "cryptsetup";
    source = sources.cryptsetup;
    script = ./autotools.sh;
    depends = [ glibc popt device-mapper json-c openssl util-linux ];
    buildDepends = [ pkgconf ];
    env = { configure_arguments = "--disable-static --disable-nls --disable-asciidoc --disable-integritysetup --disable-ssh-token --disable-external-tokens --disable-udev --disable-selinux --with-crypto_backend=openssl"; };
  };

  # mkfs.erofs, which systemd-repart runs to make the read-only file
  # systems of /usr and of extension images.  gccLibraries: it works in
  # several threads and ends them early, for which glibc loads libgcc_s
  # by name (docs/nix-usr-system.md, "libgcc_s").
  erofs-utils = mkSystemPackage {
    name = "erofs-utils";
    source = sources.erofs-utils;
    script = ./base/erofs-utils.sh;
    depends = [ glibc lz4 tools.xz zlib util-linux toolchain.gccLibraries ];
    buildDepends = [ pkgconf autoconf automake libtool ];
  };

  # curl and libcurl, with OpenSSL for TLS and Mozilla's certificates.
  # The HTTP/2 and HTTP/3 libraries, and the list of public domain
  # suffixes, are optional, and nothing here needs them.  bash: wcurl and
  # curl-config are scripts.
  curl = mkSystemPackage {
    name = "curl";
    source = sources.curl;
    script = ./autotools.sh;
    depends = [ glibc openssl zlib ca-certificates tools.bash ];
    buildDepends = [ pkgconf ];
    env = { configure_arguments = "--with-openssl --with-zlib --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt --with-ca-path=/etc/ssl/certs --without-libpsl --without-nghttp2 --without-libidn2 --without-brotli --without-zstd --without-libssh2 --disable-static --disable-manual --disable-docs --disable-ldap"; };
  };

  # Loads kernel modules: modprobe, depmod, lsmod, modinfo, and the
  # library udev loads each device's driver with.  zstd and xz: modules
  # are compressed; openssl: modinfo reads their signatures.  UAPI.9 has
  # modules in /usr/lib/modules.
  kmod = mkSystemPackage {
    name = "kmod";
    source = sources.kmod;
    script = ./meson.sh;
    depends = [ glibc zstd tools.xz openssl ];
    buildDepends = [ meson ninja pkgconf ];
    env = { meson_arguments = "-Dmoduledir=/usr/lib/modules -Dzstd=enabled -Dxz=enabled -Dzlib=disabled -Dopenssl=enabled -Dmanpages=false -Ddocs=false -Dbuild-tests=false -Dbashcompletiondir=no -Dzshcompletiondir=no"; };
  };

  # systemd, configured down to an init system and its network stack: PID
  # 1, journald, udevd, tmpfiles, sysusers, networkd, resolved, timesyncd,
  # logind, hostnamed, timedated, repart, sysext and sysupdate, and their
  # client tools (base/systemd.sh says what of the element is not on yet).
  systemd = mkSystemPackage {
    name = "systemd";
    source = sources.systemd;
    script = ./base/systemd.sh;
    depends = [ glibc libcap libxcrypt util-linux openssl kmod acl zlib tools.xz tools.bash cryptsetup curl ];
    buildDepends = [ meson ninja gperf pkgconf python-jinja2 ];
  };

  # mkfs.ext4 and e2fsck: the file system of a system's writable
  # partition.  systemd checks and makes file systems with it.
  e2fsprogs = mkSystemPackage {
    name = "e2fsprogs";
    source = sources.e2fsprogs;
    script = ./base/e2fsprogs.sh;
    # bash: compile_et and mk_cmds, which build its libraries' users, are
    # scripts.
    depends = [ glibc util-linux tools.bash ];
    buildDepends = [ pkgconf ];
  };

  # mkfs.fat: the file system of the partition a machine boots from.
  # --without-iconv: the system has none of glibc's character-set
  # converters; the table built into it is enough.
  dosfstools = mkSystemPackage {
    name = "dosfstools";
    source = sources.dosfstools;
    script = ./autotools.sh;
    depends = [ glibc ];
    env = { configure_arguments = "--enable-compat-symlinks --without-iconv"; };
  };

  # ps, top, free, pgrep and pkill, pidof, sysctl, uptime, vmstat, watch,
  # w.  kill comes from util-linux.
  procps-ng = mkSystemPackage {
    name = "procps-ng";
    source = sources.procps-ng;
    script = ./autotools.sh;
    depends = [ glibc ncurses ];
    buildDepends = [ pkgconf ];
    env = { configure_arguments = "--disable-static --disable-nls --disable-kill --without-systemd --enable-watch8bit"; };
  };

  # ping.  Only ping: arping and clockdiff need root's raw sockets.  This
  # ping asks first for the ICMP sockets the kernel gives ordinary users
  # (where net.ipv4.ping_group_range lets it, which systemd sees to), so it
  # is given no set-user-id bit and no capability, and is built without
  # the library for dropping them.  NO_SETCAP_OR_SUID, which the element
  # lacks, is iputils' default; said, because the sentence above rests
  # on it.
  iputils = mkSystemPackage {
    name = "iputils";
    source = sources.iputils;
    script = ./meson.sh;
    depends = [ glibc ];
    buildDepends = [ meson ninja pkgconf ];
    env = { meson_arguments = "-DBUILD_PING=true -DBUILD_ARPING=false -DBUILD_CLOCKDIFF=false -DBUILD_TRACEPATH=false -DBUILD_MANS=false -DUSE_CAP=false -DUSE_IDN=false -DUSE_GETTEXT=false -DNO_SETCAP_OR_SUID=true"; };
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
  # without it.  systemd starts it when something first speaks.
  dbus = mkSystemPackage {
    name = "dbus";
    source = sources.dbus;
    script = ./base/dbus.sh;
    depends = [ glibc expat systemd ];
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

  # GNU autoconf, automake and libtool: they generate the configure script
  # and makefiles of a source that comes without them (erofs-utils).
  # autoconf's programs are perl and m4.
  autoconf = mkSystemPackage {
    name = "autoconf";
    source = sources.autoconf;
    script = ./autotools.sh;
    depends = [ tools.m4 perl tools.bash ];
  };
  automake = mkSystemPackage {
    name = "automake";
    source = sources.automake;
    script = ./autotools.sh;
    depends = [ autoconf perl tools.bash ];
  };
  libtool = mkSystemPackage {
    name = "libtool";
    source = sources.libtool;
    script = ./autotools.sh;
    # coreutils: libtoolize is run by env.
    depends = [ glibc tools.m4 tools.bash tools.coreutils ];
    env = { configure_arguments = "--disable-static"; };
  };

  # A perfect hash generator: systemd's build looks its keywords up with
  # what it writes.
  gperf = mkSystemPackage {
    name = "gperf";
    source = sources.gperf;
    script = ./autotools.sh;
    depends = [ glibc toolchain.gccLibraries ];
  };

  # MarkupSafe: string escaping for Jinja2
  python-markupsafe = mkSystemPackage {
    name = "python-markupsafe";
    source = sources.python-markupsafe;
    script = ./base/python-module.sh;
    depends = [ tools.python ];
    env = { module = "markupsafe"; };
  };

  # Jinja2: the template engine systemd's build generates files with
  python-jinja2 = mkSystemPackage {
    name = "python-jinja2";
    source = sources.python-jinja2;
    script = ./base/python-module.sh;
    depends = [ tools.python python-markupsafe ];
    env = { module = "jinja2"; };
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
  inherit readline zlib bzip2 zstd openssl libmnl expat libcap libxcrypt attr acl popt json-c device-mapper dm-udev-rules lz4 ca-certificates;
  inherit util-linux cryptsetup erofs-utils curl kmod systemd e2fsprogs dosfstools procps-ng iproute2 iputils openssh dbus iwd wireless-regdb rex rust rust-std-aarch64-none;
  inherit pkgconf flex bc perl ninja autoconf automake libtool gperf python-markupsafe python-jinja2 python-zlib meson cmake llvm bindgen;
}
