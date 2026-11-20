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
#   kind: cargo with only cargo-install-local
#                      -> script = ./cargo.sh; env.cargo_arguments; its
#                         cargo2 source -> base/x-crates.json, env.crates
#   environment        -> env, under the same names
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

  # Linux-PAM: how login, sshd, run0 and systemd's user manager check
  # passwords and open sessions (pam_systemd registers them with logind:
  # /run/user/<uid>, a user's own services).  Its modules only; bunix's
  # rules are files/rootfs/usr/lib/pam.d, which PAM reads after
  # /etc/pam.d, so an update brings new defaults and an administrator's
  # own files still win.
  # logind off: it is for two modules this system does not use, and
  # systemd is built on PAM, not the other way round.
  # bash: pam_namespace_helper is a script.
  linux-pam = mkSystemPackage {
    name = "linux-pam";
    source = sources.linux-pam;
    script = ./meson.sh;
    depends = [ glibc libxcrypt tools.bash ];
    buildDepends = [ meson ninja pkgconf ];
    env = { meson_arguments = "-Di18n=disabled -Ddocs=disabled -Daudit=disabled -Deconf=disabled -Dlogind=disabled -Delogind=disabled -Dselinux=disabled -Dnis=disabled -Dpwaccess=disabled -Dpam_userdb=disabled -Dexamples=false -Dxtests=false"; };
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

  # Calls into C whose shape is known only when the program runs: Python's
  # ctypes is made of it.  --disable-multi-os-directory: otherwise it adds
  # gcc's own name for the directory to --libdir.
  libffi = mkSystemPackage {
    name = "libffi";
    source = sources.libffi;
    script = ./autotools.sh;
    depends = [ glibc ];
    env = { configure_arguments = "--disable-static --disable-docs --disable-multi-os-directory"; };
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
    depends = [ glibc libcap libxcrypt linux-pam util-linux openssl kmod acl zlib tools.xz tools.bash cryptsetup curl ];
    buildDepends = [ meson ninja gperf pkgconf python-jinja2 python-pyelftools python-ctypes ];
  };

  # shadow: the tools that manage users and groups: useradd, usermod,
  # userdel, groupadd, groupmod, groupdel, chage, and passwd and chpasswd,
  # which set passwords through PAM.  /etc/login.defs and
  # /etc/default/useradd reach a system on a disk through
  # /usr/share/factory/etc.
  # systemd: userdel and usermod ask logind, and refuse to change a user
  # who is logged in.
  shadow = mkSystemPackage {
    name = "shadow";
    source = sources.shadow;
    script = ./base/shadow.sh;
    depends = [ glibc libxcrypt linux-pam systemd ];
    buildDepends = [ pkgconf ];
  };

  # login and runuser from util-linux, with PAM: the console's login
  # prompt (console-shell@.service), whose sessions logind knows, and
  # runuser, root's way to run something as another user.  A build of its
  # own from the source of util-linux, which systemd itself is built on:
  # PAM there would rebuild most of the system.  No su: run0 is the way up.
  util-linux-login = mkSystemPackage {
    name = "util-linux-login";
    source = sources.util-linux;
    script = ./base/util-linux-login.sh;
    depends = [ glibc linux-pam ];
    buildDepends = [ pkgconf ];
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
  # only, no passwords (files/rootfs/etc/ssh/sshd_config).  With PAM for
  # accounts and sessions only (files/rootfs/usr/lib/pam.d/sshd), so a
  # login over SSH is a session logind knows.
  openssh = mkSystemPackage {
    name = "openssh";
    source = sources.openssh;
    script = ./base/openssh.sh;
    depends = [ glibc openssl zlib linux-pam ];
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
    env = { module_paths = "src/markupsafe"; };
  };

  # Jinja2: the template engine systemd's build generates files with
  python-jinja2 = mkSystemPackage {
    name = "python-jinja2";
    source = sources.python-jinja2;
    script = ./base/python-module.sh;
    depends = [ tools.python python-markupsafe ];
    env = { module_paths = "src/jinja2"; };
  };

  # pyelftools: systemd's build turns the ELF programs of systemd-boot
  # into EFI ones with it.
  python-pyelftools = mkSystemPackage {
    name = "python-pyelftools";
    source = sources.python-pyelftools;
    script = ./base/python-module.sh;
    depends = [ tools.python ];
    env = { module_paths = "elftools"; };
  };

  # pefile: ukify puts a unified kernel image together with it.
  python-pefile = mkSystemPackage {
    name = "python-pefile";
    source = sources.python-pefile;
    script = ./base/python-module.sh;
    depends = [ tools.python ];
    env = { module_paths = "pefile.py peutils.py ordlookup"; };
  };

  # mcopy, which systemd-repart fills a FAT partition with: the one a
  # machine boots from.
  mtools = mkSystemPackage {
    name = "mtools";
    source = sources.mtools;
    script = ./autotools.sh;
    # bash: a few of its programs are scripts.
    depends = [ glibc tools.bash ];
    # bzip2: its source is packed with it
    buildDepends = [ bzip2 ];
    env = { configure_arguments = "--without-x"; };
  };

  # Python's modules that need a library.  The Python that builds run
  # (tools.nix) is built before any library, and has only the modules that
  # need none; each of the others is a package like these, of Python's own
  # source, laid over it (base/python-extension.sh).

  # zlib: meson reads gzip when it starts.  HAVE_ZLIB_COPY: without it, no
  # copy() of a stream.
  python-zlib = mkSystemPackage {
    name = "python-zlib";
    source = sources.python;
    script = ./base/python-extension.sh;
    depends = [ glibc tools.python zlib ];
    env = {
      module = "zlib";
      c_files = "Modules/zlibmodule.c";
      flags = "-DHAVE_ZLIB_COPY=1 -lz";
      try = "import zlib; zlib.decompressobj().copy()";
    };
  };

  # ctypes, calls into C from Python: systemd's build makes EFI programs
  # of systemd-boot's with a script that uses it.  The three HAVE_... are
  # what libffi has had for years.
  python-ctypes = mkSystemPackage {
    name = "python-ctypes";
    source = sources.python;
    script = ./base/python-extension.sh;
    depends = [ glibc tools.python libffi ];
    env = {
      module = "_ctypes";
      c_files = "Modules/_ctypes/_ctypes.c Modules/_ctypes/callbacks.c Modules/_ctypes/callproc.c Modules/_ctypes/stgdict.c Modules/_ctypes/cfield.c";
      flags = "-DHAVE_FFI_PREP_CIF_VAR=1 -DHAVE_FFI_PREP_CLOSURE_LOC=1 -DHAVE_FFI_CLOSURE_ALLOC=1 -lffi -ldl";
      try = "import ctypes; ctypes.CDLL(None).getpid()";
    };
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
  # bindgen.sh is cargo.sh's lines and the patches: a fix to one is a fix
  # to the other.
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

  # Botan 3: the C++ cryptography library behind Sequoia (sqv).
  # Sequoia's other backends fit for use, OpenSSL and Nettle, reach C
  # through bindgen; Botan's Rust bindings are written by hand.  A static
  # library only: it is linked into the programs, and nothing of it is in
  # a system.
  botan = mkSystemPackage {
    name = "botan";
    source = sources.botan;
    script = ./base/botan.sh;
    depends = [ glibc ];
    buildDepends = [ tools.python ];
  };

  # sqv: Sequoia's verifier of OpenPGP signatures.  systemd-sysupdate
  # checks the signature of an update's list of files (SHA256SUMS.gpg) by
  # running `gpg`; bunix's gpg is a small script that hands that check to
  # sqv (files/rootfs/usr/bin/gpg; docs/updates.md says why not GnuPG).
  # gccLibraries: Botan is C++.
  sqv = mkSystemPackage {
    name = "sqv";
    source = sources.sqv;
    script = ./cargo.sh;
    depends = [ glibc toolchain.gccLibraries ];
    buildDepends = [ rust pkgconf botan ];
    env = {
      cargo_arguments = "--no-default-features --features crypto-botan";
      # Botan's Rust bindings do not say that the C++ library is to be
      # linked.  The element links libstdc++.a into the program, x86's
      # system having no libstdc++.so; this one has (images/system.nix).
      RUSTFLAGS = "-C link-arg=-lstdc++";
      # sqv's Cargo.lock, as the `cargo2` source of elements/base/sqv.bst
      # has it
      crates = map (crate: fetch {
        url = "https://static.crates.io/crates/${crate.name}/${crate.name}-${crate.version}.crate";
        inherit (crate) sha256;
      }) (builtins.fromJSON (builtins.readFile ./base/sqv-crates.json));
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
  inherit readline zlib bzip2 zstd openssl libmnl expat libcap libxcrypt linux-pam shadow util-linux-login libffi attr acl popt json-c device-mapper dm-udev-rules lz4 ca-certificates;
  inherit util-linux cryptsetup erofs-utils curl kmod systemd e2fsprogs dosfstools procps-ng iproute2 iputils openssh dbus iwd wireless-regdb rex rust rust-std-aarch64-none;
  inherit pkgconf flex bc perl ninja autoconf automake libtool gperf mtools python-markupsafe python-jinja2 python-pyelftools python-pefile python-zlib python-ctypes meson cmake llvm bindgen botan sqv;
}
