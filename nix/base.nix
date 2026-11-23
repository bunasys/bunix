# Packages of a bunix system, after elements/base/: each is built with the
# system's own compiler and tools (tools.nix), and nothing of the bootstrap.
# The exceptions are under "Programs built elsewhere".
#
# An element is removed once it is ported, so most of those named here
# are gone from elements/: `git show v0.4.0:elements/base/x.bst` has one.
# What is still there is what is left to port.
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

  # libelf and libdw.  What checks and annotates the kernel's object code
  # on x86 (objtool) reads ELF files with libelf.  libdw is for pahole,
  # which makes the kernel's BTF and is not a package yet
  # (boot/linux/x86_64.config).
  elfutils = mkSystemPackage {
    name = "elfutils";
    source = sources.elfutils;
    script = ./base/elfutils.sh;
    depends = [ glibc zlib ];
    # bzip2: the source's archive is compressed with it
    buildDepends = [ pkgconf bzip2 ];
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

  # Perl-compatible regular expressions, for GLib.  bzip2: its source is
  # a .tar.bz2.  bash: pcre2-config is a script.
  pcre2 = mkSystemPackage {
    name = "pcre2";
    source = sources.pcre2;
    script = ./autotools.sh;
    depends = [ glibc tools.bash ];
    buildDepends = [ bzip2 ];
    env = { configure_arguments = "--disable-static --enable-jit"; };
  };

  # GLib: the C utility, object (GObject) and I/O (GIO) libraries that
  # polkit is built on, and later GTK, pango, Qt and niri.  No
  # introspection, no SELinux, no sysprof.
  # bash: glib-gettextize is a script.
  glib = mkSystemPackage {
    name = "glib";
    source = sources.glib;
    script = ./base/glib.sh;
    depends = [ glibc libffi pcre2 zlib util-linux tools.bash ];
    buildDepends = [ meson ninja pkgconf python-packaging ];
  };

  # Duktape: a small JavaScript interpreter, which polkit runs its rules
  # (/usr/share/polkit-1/rules.d) in.
  duktape = mkSystemPackage {
    name = "duktape";
    source = sources.duktape;
    script = ./base/duktape.sh;
    depends = [ glibc ];
    env = { duktape_version = sources.duktape.version; };
  };

  # pixman: pixel compositing on the CPU, which QEMU draws a virtual
  # machine's screen with.
  pixman = mkSystemPackage {
    name = "pixman";
    source = sources.pixman;
    script = ./meson.sh;
    depends = [ glibc ];
    buildDepends = [ meson ninja pkgconf ];
    env = { meson_arguments = "-Dtests=disabled -Ddemos=disabled -Dgtk=disabled -Dlibpng=disabled -Dopenmp=disabled"; };
  };

  # libslirp: a network in a library (TCP/IP, DHCP, DNS forwarding), which
  # gives a virtual machine of QEMU's a way out through the sockets of
  # whoever runs it: no root, and no device on the host.  No element.
  libslirp = mkSystemPackage {
    name = "libslirp";
    source = sources.libslirp;
    script = ./meson.sh;
    depends = [ glibc glib ];
    buildDepends = [ meson ninja pkgconf ];
  };

  # libfdt, of the device tree compiler: QEMU writes with it the device
  # tree that describes a virtual machine to its kernel (every aarch64
  # one).  No element.  The library alone, not the compiler and its
  # Python module (tools, python), nor what only they or the tests use.
  # default_library=shared: its own default builds a static one as well,
  # which no system package has.
  # werror=false: its own default is to fail on any warning, of whatever
  # compiler comes later.
  dtc = mkSystemPackage {
    name = "dtc";
    source = sources.dtc;
    script = ./meson.sh;
    depends = [ glibc ];
    buildDepends = [ meson ninja pkgconf ];
    env = { meson_arguments = "-Ddefault_library=shared -Dwerror=false -Dtools=false -Dtests=false -Dpython=disabled -Dyaml=disabled -Dvalgrind=disabled"; };
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
  # And chsh, which the element does not have (base/util-linux-login.sh).
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

  # polkit: decides which user may do which privileged thing (run0,
  # setting the time), from rules in JavaScript.  Members of the wheel
  # group are administrators: polkit asks them for their own password.
  # gettext: msgfmt merges the actions' descriptions into their .policy
  #   files.
  # perl: turns the JavaScript init file into a C string.
  polkit = mkSystemPackage {
    name = "polkit";
    source = sources.polkit;
    script = ./base/polkit.sh;
    depends = [ glibc duktape expat glib linux-pam systemd ];
    buildDepends = [ meson ninja pkgconf gettext perl ];
  };

  # iwd, the wireless daemon: scans, authenticates and keeps the link up,
  # and leaves addresses to whatever hands them out.  iwctl is its client.
  # On arm64 the chip's firmware is not a package
  # (boot/linux/aarch64.config); on x86 it is boot.nix's firmware.
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

  # ---- Tools for working on software -----------------------------------------
  # What the devtools extension is made of (images/devtools.nix), not the
  # system: a machine has them when its person asks for the extension.

  # strace: traces a program's system calls and signals.  Without the
  # second and third personality (32-bit programs on a 64-bit kernel),
  # which need a compiler for them, and without stack traces.  bash:
  # strace-log-merge is a script.
  strace = mkSystemPackage {
    name = "strace";
    source = sources.strace;
    script = ./autotools.sh;
    depends = [ glibc ncurses tools.bash ];
    env = { configure_arguments = "--enable-mpers=no --disable-gcc-Werror --without-libdw --without-libunwind"; };
  };

  # file and libmagic: identifies a file's type by its contents.
  file = mkSystemPackage {
    name = "file";
    source = sources.file;
    script = ./base/file.sh;
    depends = [ glibc bzip2 tools.xz zlib zstd ];
  };

  # libarchive: bsdtar, which reads and writes zip, 7-Zip, ISO 9660 and
  # the tar and cpio formats, and bsdunzip, installed as unzip.  A zip is
  # made with `bsdtar -a -cf name.zip files...`.
  libarchive = mkSystemPackage {
    name = "libarchive";
    source = sources.libarchive;
    script = ./base/libarchive.sh;
    depends = [ glibc bzip2 lz4 openssl tools.xz zlib zstd ];
    buildDepends = [ pkgconf ];
  };

  # Git.  HTTPS through libcurl, `git grep -P` through PCRE2.  Without the
  # parts written in Perl, Python and Tcl/Tk (send-email, svn, gitk, git
  # gui), and without the Rust parts, which build with Cargo.  bash: some
  # of its commands are scripts.
  git = mkSystemPackage {
    name = "git";
    source = sources.git;
    script = ./base/git.sh;
    depends = [ glibc curl expat openssl pcre2 zlib tools.bash ];
    buildDepends = [ pkgconf ];
  };

  # Node.js 24 with npm and corepack, for the devtools extension.  The
  # element, up to 0.4.0, was only what Hudhud is built with, and had
  # neither (--without-npm --without-corepack, not passed here).  24 is
  # the major version Chromium checks for (docs/browser.md; Hudhud is
  # not ported yet), so the version follows Chromium's; anyone who needs
  # another Node fetches it themselves.  Node's own copies of V8, ICU,
  # OpenSSL and the rest.
  # coreutils: npm and corepack are scripts that `env` finds node for.
  nodejs = mkSystemPackage {
    name = "nodejs";
    source = sources.nodejs;
    script = ./base/nodejs.sh;
    depends = [ glibc toolchain.gccLibraries tools.coreutils ];
    # python-bz2: Node's configure script imports it when it starts;
    # python-ctypes: so does gyp, which writes ninja's files;
    # python-zlib: a build script compresses with it the description of
    # what a debugger can ask of Node.
    buildDepends = [ ninja python-bz2 python-ctypes python-zlib ];
  };

  # GMP: arbitrary-precision arithmetic (gdb evaluates expressions with
  # it).  The compiler has its own copy, built into it.
  gmp = mkSystemPackage {
    name = "gmp";
    source = sources.gmp;
    script = ./base/gmp.sh;
    depends = [ glibc ];
  };

  # MPFR: floating point with exact rounding (gdb's floating-point
  # expressions).
  mpfr = mkSystemPackage {
    name = "mpfr";
    source = sources.mpfr;
    script = ./autotools.sh;
    depends = [ glibc gmp ];
    env = { configure_arguments = "--disable-static"; };
  };

  # GDB, the GNU debugger, and gdbserver.  With its text interface (gdb
  # -tui) and compressed debug sections (zlib, zstd, xz); without Python
  # and Guile scripting and debuginfod.  gccLibraries: it is C++.  bash,
  # coreutils and gawk: gstack is a script, started by env, that uses awk.
  gdb = mkSystemPackage {
    name = "gdb";
    source = sources.gdb;
    script = ./autotools.sh;
    depends = [ glibc expat gmp mpfr ncurses readline tools.xz zlib zstd toolchain.gccLibraries tools.bash tools.coreutils tools.gawk ];
    buildDepends = [ pkgconf ];
    env = { configure_arguments = "--disable-nls --disable-werror --disable-sim --disable-gprofng --with-system-readline --with-system-zlib --with-zstd --with-lzma --with-expat --enable-tui --without-python --without-guile --without-debuginfod --without-babeltrace --without-xxhash --without-intel-pt"; };
  };

  # QEMU: whole virtual machines, of the architecture it runs on, with
  # KVM (/dev/kvm) -- firmware, disks, a screen, a network.  What bunix
  # is tested in as a machine with EFI starts it
  # (docs/nix-usr-system.md, "QEMU").  No element, and in no image yet.
  # base/qemu.sh has what is built, and where the firmware comes from.
  qemu = mkSystemPackage {
    name = "qemu";
    source = sources.qemu;
    script = ./base/qemu.sh;
    depends = [ glibc glib pixman libslirp dtc zlib ];
    # python-zlib: the build unpacks the meson that QEMU's source carries.
    # bzip2: and the firmware it carries, which is compressed.
    buildDepends = [ ninja pkgconf python-zlib bzip2 ];
    env = { patches = [ ../files/qemu/no-test-tooling.patch ]; };
  };

  # ---- Programs built elsewhere ----------------------------------------------

  # Nix, for the devtools extension: what bunix is built by, on a bunix.
  # The one program, linked with all it needs, as the Nix project's own
  # builds publish it for each architecture (sources.json: a build of
  # their maintenance-2.35 jobs, by its number).  Not built here yet:
  # that is Nix and ten libraries this system does not have.  With it,
  # bunix's own: the daemon's units, and settings for /etc (files/nix/).
  nix = mkSystemPackage {
    name = "nix";
    source = sources."nix-${system}";
    script = ./base/nix.sh;
    builtElsewhere = true;
    env = { files = ../files/nix; };
  };

  # Firecracker: microVMs on KVM (/dev/kvm), with jailer, which starts it
  # in a chroot, namespaces and cgroup of its own.  Upstream's own static
  # release build, not built here: its seccomp filters (the system calls
  # the VMM may make) exist only for the musl build, which bunix's Rust
  # cannot target, and a glibc build runs with an empty filter.  For
  # x86_64 only so far, as its element was: the release for aarch64 has
  # not been tried on a Mac.
  firecracker = mkSystemPackage {
    name = "firecracker";
    source = sources."firecracker-${system}";
    script = ./base/firecracker.sh;
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

  # packaging: version parsing, for GLib's build
  python-packaging = mkSystemPackage {
    name = "python-packaging";
    source = sources.python-packaging;
    script = ./base/python-module.sh;
    depends = [ tools.python ];
    env = { module_paths = "src/packaging"; };
  };

  # pefile: ukify puts a unified kernel image together with it.
  python-pefile = mkSystemPackage {
    name = "python-pefile";
    source = sources.python-pefile;
    script = ./base/python-module.sh;
    depends = [ tools.python ];
    env = { module_paths = "pefile.py peutils.py ordlookup"; };
  };

  # GNU gettext: the translation tools (xgettext, msgfmt, ...).  glibc has
  # the run-time side (libintl) already.
  # gccLibraries: one of its libraries is C++.  bash: gettextize and
  # autopoint are shell scripts.  python, coreutils: its program spit is
  # a Python script, started through env.  Python is why gettext is a
  # tool of builds and not in an image.
  gettext = mkSystemPackage {
    name = "gettext";
    source = sources.gettext;
    script = ./autotools.sh;
    depends = [ glibc ncurses toolchain.gccLibraries tools.bash tools.coreutils tools.python ];
    env = { configure_arguments = "--disable-static --disable-java --disable-csharp --disable-d --disable-modula2 --disable-go --disable-openmp --disable-rpath"; };
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

  # bz2: Node's configure script imports it when it starts.
  python-bz2 = mkSystemPackage {
    name = "python-bz2";
    source = sources.python;
    script = ./base/python-extension.sh;
    depends = [ glibc tools.python bzip2 ];
    env = {
      module = "_bz2";
      c_files = "Modules/_bz2module.c";
      flags = "-lbz2";
      try = "import bz2; bz2.decompress(bz2.compress(b'bunix'))";
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

  # bunix: the command a person looks after their system with (update,
  # ext), written here (src/bunix).  Rust's standard library and nothing
  # else, so cargo is given no crates.
  # gccLibraries: a Rust program asks for libgcc_s.
  bunix-command = mkSystemPackage {
    name = "bunix-command";
    # as src/bunix/Cargo.toml has it
    version = "0.1.0";
    script = ./base/bunix-command.sh;
    depends = [ glibc toolchain.gccLibraries ];
    buildDepends = [ rust ];
    env = {
      source_directory = builtins.path {
        name = "bunix-command-source";
        path = ../src/bunix;
        # The source and nothing beside it: not target/, which cargo
        # leaves when it is run by hand there, nor what an editor or a
        # Mac's Finder leaves.  Any of those would make another package.
        filter = path: type:
          let name = baseNameOf path; in
          name == "Cargo.toml" || name == "Cargo.lock" || name == "src" || builtins.match ".*\\.rs" name != null;
      };
    };
  };

  # osslsigncode: signs a kernel image for Secure Boot, as a PC's
  # firmware and shim check it (tools/sign-kernel-image.sh).  Not in any
  # image: a build of a test system signs its kernel image with it
  # (images/uki.nix), and a release is signed with the same script on a
  # Mac, with Homebrew's.  OpenSSL 3 fetches what a signature's time
  # stamp needs itself, so not curl.
  osslsigncode = mkSystemPackage {
    name = "osslsigncode";
    source = sources.osslsigncode;
    script = ./cmake.sh;
    depends = [ glibc openssl zlib ];
    buildDepends = [ cmake ninja pkgconf ];
  };

  # boot-picture: draws the picture of a boot again on a screen that a
  # GPU's driver has just taken, so that the picture is there and a
  # kernel that stops has something to draw on (src/boot-picture, which
  # says more; docs/nix-usr-system.md, "What a boot shows").  udev runs
  # it, by the rule it comes with.  Rust's standard library and nothing
  # else, as bunix-command.
  boot-picture = mkSystemPackage {
    name = "boot-picture";
    # as src/boot-picture/Cargo.toml has it
    version = "0.1.0";
    script = ./base/boot-picture.sh;
    depends = [ glibc toolchain.gccLibraries ];
    buildDepends = [ rust ];
    env = {
      source_directory = builtins.path {
        name = "boot-picture-source";
        path = ../src/boot-picture;
        # the source and nothing beside it, as bunix-command's
        filter = path: type:
          let name = baseNameOf path; in
          name == "Cargo.toml" || name == "Cargo.lock" || name == "src" || builtins.match ".*\\.rs" name != null;
      };
      # the picture systemd's stub draws (images/uki.nix): the same file
      picture = ../files/branding/splash.bmp;
      rule = ./base/boot-picture.rules;
    };
  };

  # fish: a shell a user may choose in place of bash (chsh).  Written in
  # Rust; it brings its own PCRE2, which its build compiles.
  # ncurses: fish reads the terminfo database when it runs.
  fish = mkSystemPackage {
    name = "fish";
    source = sources.fish;
    script = ./base/fish.sh;
    depends = [ glibc toolchain.gccLibraries ncurses ];
    buildDepends = [ rust cmake ninja ];
    env = {
      # fish's Cargo.lock, as the `cargo2` source of elements/base/fish.bst
      # has it
      crates = map (crate: fetch {
        url = "https://static.crates.io/crates/${crate.name}/${crate.name}-${crate.version}.crate";
        inherit (crate) sha256;
      }) (builtins.fromJSON (builtins.readFile ./base/fish-crates.json));
      # and the three git repositories that the rest of its crates are in,
      # each at the commit the element's `kind: git` crates name (its
      # version in sources.json)
      fluent_rs = fetch sources.fish-fluent-rs;
      fluent_ftl_tools = fetch sources.fish-fluent-ftl-tools;
      rust_pcre2 = fetch sources.fish-rust-pcre2;
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
  inherit readline zlib bzip2 elfutils zstd openssl libmnl expat libcap libxcrypt linux-pam shadow util-linux-login libffi pcre2 glib duktape attr acl popt json-c device-mapper dm-udev-rules lz4 ca-certificates;
  inherit util-linux cryptsetup erofs-utils curl kmod systemd e2fsprogs dosfstools procps-ng iproute2 iputils openssh dbus polkit iwd wireless-regdb rust rust-std-aarch64-none;
  inherit strace file libarchive git nodejs gmp mpfr gdb nix firecracker pixman libslirp dtc qemu;
  inherit pkgconf flex bc perl ninja autoconf automake libtool gperf mtools python-markupsafe python-jinja2 python-pyelftools python-pefile python-packaging python-zlib python-bz2 python-ctypes meson gettext cmake llvm bindgen botan sqv fish bunix-command boot-picture osslsigncode;
}
