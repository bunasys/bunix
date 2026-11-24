# Packages of the graphical system, after elements/base/ and
# elements/desktop/: what the desktop extension is made of
# (images/desktop.nix), and what only their builds need.  None of them is
# in the system itself.  Built as base.nix's are, and ported from the
# elements the way it says.
#
#   nix-build /bunix/nix/desktop.nix -A niri
#
# docs/desktop.md has the plan and how far it has come.
{ system ? builtins.currentSystem }:

let
  toolchain = import ./toolchain.nix { inherit system; };
  tools = import ./tools.nix { inherit system; };
  base = import ./base.nix { inherit system; };
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  fetch = import ./fetch.nix;
  architecture = import ./architecture.nix system;
  inherit (toolchain) glibc;
  inherit (base) meson ninja pkgconf;

  mkSystemPackage = import ./system-package.nix {
    inherit system;
    inherit (tools) buildEnvironment;
    defaultEnv = tools.compilerFlags;
  };

  # ---- Drawing: the GPU's drivers ---------------------------------------------

  # libdrm: the kernel's graphics interface (DRM and KMS) from programs:
  # what Mesa and the compositor reach the GPU and the screen through.
  # With the libraries of the GPUs whose Mesa drivers use one (amdgpu and
  # radeon for radeonsi; nouveau and vmwgfx, as the element); intel's
  # needs libpciaccess, and Mesa's Intel drivers do not use it.
  libdrm = mkSystemPackage {
    name = "libdrm";
    source = sources.libdrm;
    script = ./meson.sh;
    depends = [ glibc ];
    buildDepends = [ meson ninja pkgconf ];
    env = { meson_arguments = "-Damdgpu=enabled -Dradeon=enabled -Dnouveau=enabled -Dvmwgfx=enabled -Dintel=disabled -Domap=disabled -Dexynos=disabled -Dfreedreno=disabled -Dtegra=disabled -Dvc4=disabled -Detnaviv=disabled -Dcairo-tests=disabled -Dman-pages=disabled -Dvalgrind=disabled -Dtests=false -Dudev=true"; };
  };

  # Wayland: the protocol between the compositor (niri) and the programs
  # it shows: libwayland-client and -server, and wayland-scanner, which
  # turns a protocol's description into C for a build.
  wayland = mkSystemPackage {
    name = "wayland";
    source = sources.wayland;
    script = ./meson.sh;
    depends = [ glibc base.expat base.libffi ];
    buildDepends = [ meson ninja pkgconf ];
    env = { meson_arguments = "-Dtests=false -Ddocumentation=false -Ddtd_validation=false"; };
  };

  # The protocols beyond Wayland's own (xdg shell, fractional scaling,
  # ...), as descriptions for wayland-scanner: for builds only.
  wayland-protocols = mkSystemPackage {
    name = "wayland-protocols";
    source = sources.wayland-protocols;
    script = ./meson.sh;
    buildDepends = [ meson ninja pkgconf wayland ];
    env = { meson_arguments = "-Dtests=false"; };
  };

  # Mako: the template engine Mesa's build generates code with
  python-mako = mkSystemPackage {
    name = "python-mako";
    source = sources.python-mako;
    script = ./base/python-module.sh;
    depends = [ tools.python base.python-markupsafe ];
    env = { module_paths = "mako"; };
  };

  # PyYAML: Mesa's build reads its drivers' tables with it.  Python only,
  # without libyaml.
  python-pyyaml = mkSystemPackage {
    name = "python-pyyaml";
    source = sources.python-pyyaml;
    script = ./base/python-module.sh;
    depends = [ tools.python ];
    env = { module_paths = "lib/yaml"; };
  };

  # SPIR-V, the GPU's intermediate language, as Mesa's build compiles
  # some of its drivers' own programs to it (desktop/mesa.sh says which):
  # the language's grammar and headers; the tools that check and shrink
  # it; and LLVM's way to it from C.  The last two as static libraries,
  # for Mesa's build alone.  The headers are the commit the translator
  # names (its spirv-headers-tag.conf), whose newest instructions it
  # uses; the translator's major version is LLVM's.
  spirv-headers = mkSystemPackage {
    name = "spirv-headers";
    source = sources.spirv-headers;
    script = ./cmake.sh;
    buildDepends = [ base.cmake ninja ];
  };
  spirv-tools = mkSystemPackage {
    name = "spirv-tools";
    source = sources.spirv-tools;
    script = ./cmake.sh;
    # gccLibraries: its tools, and a shared library it installs beside
    # the static ones, are C++.  bash, coreutils: spirv-lesspipe.sh is a
    # script, started through env.
    depends = [ glibc toolchain.gccLibraries tools.bash tools.coreutils ];
    buildDepends = [ base.cmake ninja spirv-headers ];
    env = { cmake_arguments = "-DSPIRV-Headers_SOURCE_DIR=/usr -DBUILD_SHARED_LIBS=OFF -DSPIRV_TOOLS_BUILD_STATIC=ON -DSPIRV_SKIP_TESTS=ON -DSPIRV_WERROR=OFF"; };
  };
  spirv-llvm-translator = mkSystemPackage {
    name = "spirv-llvm-translator";
    source = sources.spirv-llvm-translator;
    script = ./cmake.sh;
    # its program, llvm-spirv, beside the library: LLVM's and C++
    depends = [ glibc toolchain.gccLibraries base.llvm ];
    buildDepends = [ base.cmake ninja pkgconf spirv-headers ];
    env = { cmake_arguments = "-DLLVM_DIR=/usr/lib/${architecture.triplet}/cmake/llvm -DBUILD_SHARED_LIBS=OFF -DLLVM_EXTERNAL_SPIRV_HEADERS_SOURCE_DIR=/usr -DLLVM_SPIRV_INCLUDE_TESTS=OFF"; };
  };

  # Mesa: OpenGL and OpenGL ES through EGL and GBM, for Wayland, with a
  # driver for each GPU bunix runs on, and llvmpipe, which draws with the
  # processor where there is none it knows.  No GLX (there is no X
  # server), no Vulkan yet, no video.  desktop/mesa.sh has the drivers of
  # each architecture, and why LLVM is inside it.
  # gccLibraries: it is C++.  zlib, zstd: LLVM, inside it, needs them.
  #
  # On arm64, Aurora's Mesa: its asahi driver draws with the GPUs of the
  # M3 and later Macs too, where upstream's has only the M1's and M2's.
  # It speaks the GPU interface of Aurora's kernel (boot.nix), so it is
  # the commit Aurora's own distributions ship with that kernel's
  # (nixos-aurora's sources.json, alarm-aurora's mesa-aurora), and moves
  # with it.  x86-64 has upstream's.
  mesa = mkSystemPackage {
    name = "mesa";
    source = if system == "aarch64-linux" then sources.mesa-aurora else sources.mesa;
    script = ./desktop/mesa.sh;
    depends = [ glibc toolchain.gccLibraries base.elfutils libdrm wayland base.expat base.zlib base.zstd ];
    # python-ctypes: a generator of the Intel compiler's tables imports it
    buildDepends = [ meson ninja pkgconf base.flex python-mako python-pyyaml base.python-packaging base.python-ctypes wayland-protocols base.llvm spirv-headers spirv-tools spirv-llvm-translator ];
    env = {
      # radeonsi's, which is built for x86-64 alone
      patches = if system == "x86_64-linux" then [ ../files/mesa/radeonsi-without-llvm-amdgpu.patch ] else [];
    };
  };

  # ---- Input ------------------------------------------------------------------

  # libevdev: reads input devices (keyboards, touch screens) from the
  # kernel's evdev interface, for libinput.
  libevdev = mkSystemPackage {
    name = "libevdev";
    source = sources.libevdev;
    script = ./meson.sh;
    depends = [ glibc ];
    buildDepends = [ meson ninja pkgconf ];
    env = { meson_arguments = "-Dtests=disabled -Ddocumentation=disabled"; };
  };

  # mtdev: turns older touch screens' multitouch events into slots, for
  # libinput.  Its home, bitmath.org, has let its certificate run out:
  # the same file from the Linux From Scratch mirror at OSU (the sha256 is
  # the element's).  bzip2: the archive is compressed with it.
  mtdev = mkSystemPackage {
    name = "mtdev";
    source = sources.mtdev;
    script = ./autotools.sh;
    depends = [ glibc ];
    buildDepends = [ base.bzip2 ];
    env = { configure_arguments = "--disable-static"; };
  };

  # libinput: keyboards, mice, touchpads and touch screens for the
  # compositor: gestures, palm detection, acceleration, and the quirks of
  # devices it knows.  Without libwacom: a tablet is a pointer like any
  # other.  bzip2: the archive is compressed with it.
  libinput = mkSystemPackage {
    name = "libinput";
    source = sources.libinput;
    script = ./meson.sh;
    depends = [ glibc libevdev mtdev base.systemd ];
    buildDepends = [ meson ninja pkgconf base.bzip2 ];
    env = { meson_arguments = "-Dudev-dir=/usr/lib/udev -Dlibwacom=false -Ddebug-gui=false -Dtests=false -Ddocumentation=false -Dlua-plugins=disabled -Dzshcompletiondir=no"; };
  };

  # seatd and libseat: give the compositor the screens and input devices
  # without running it as root.  In a session logind knows, libseat asks
  # logind; seatd's own daemon is for one started outside of a session,
  # as root at a console: `seatd-launch niri`.
  seatd = mkSystemPackage {
    name = "seatd";
    source = sources.seatd;
    script = ./meson.sh;
    depends = [ glibc base.systemd ];
    buildDepends = [ meson ninja pkgconf ];
    env = { meson_arguments = "-Dlibseat-logind=systemd -Dlibseat-seatd=enabled -Dlibseat-builtin=enabled -Dserver=enabled -Dexamples=disabled -Dman-pages=disabled"; };
  };

  # The keyboard layouts, Arabic and English among them, as data for
  # xkbcommon.  perl: its build writes some of them with it.
  xkeyboard-config = mkSystemPackage {
    name = "xkeyboard-config";
    source = sources.xkeyboard-config;
    script = ./meson.sh;
    buildDepends = [ meson ninja pkgconf base.perl ];
    env = { meson_arguments = "-Dnls=false -Dxorg-rules-symlinks=true"; };
  };

  # libxkbcommon: turns key presses into characters, by a layout of
  # xkeyboard-config's.  Without its X11 and Wayland parts and its tools.
  libxkbcommon = mkSystemPackage {
    name = "libxkbcommon";
    source = sources.libxkbcommon;
    script = ./meson.sh;
    depends = [ glibc xkeyboard-config ];
    buildDepends = [ meson ninja pkgconf ];
    env = { meson_arguments = "-Denable-x11=false -Denable-wayland=false -Denable-xkbregistry=false -Denable-tools=false -Denable-docs=false -Denable-bash-completion=false"; };
  };

  # ---- Text --------------------------------------------------------------------

  # libpng: PNG pictures (FreeType's colour glyphs, cairo)
  libpng = mkSystemPackage {
    name = "libpng";
    source = sources.libpng;
    script = ./autotools.sh;
    # bash: libpng-config is a script
    depends = [ glibc base.zlib tools.bash ];
    env = { configure_arguments = "--disable-static"; };
  };

  # FreeType: reads font files and draws their letters.  Without
  # HarfBuzz, which is built on it: FreeType would use it only to hint
  # fonts that come without hints, and each would need the other.
  freetype = mkSystemPackage {
    name = "freetype";
    source = sources.freetype;
    script = ./meson.sh;
    depends = [ glibc base.zlib base.bzip2 libpng ];
    buildDepends = [ meson ninja pkgconf ];
    env = { meson_arguments = "-Dharfbuzz=disabled -Dbrotli=disabled -Dpng=enabled -Dbzip2=enabled -Dzlib=system -Dtests=disabled"; };
  };

  # Fontconfig: finds fonts by name, language and style, for every program
  # that draws text.  Its configuration is in /usr/share/fontconfig, not
  # /etc/fonts: an extension has only /usr.  With bunix's rule for which
  # fonts sans-serif, serif and monospace are, and a unit that makes the
  # font cache, in /var, at every start (desktop/fontconfig.sh).
  fontconfig = mkSystemPackage {
    name = "fontconfig";
    source = sources.fontconfig;
    script = ./desktop/fontconfig.sh;
    depends = [ glibc freetype base.expat ];
    buildDepends = [ meson ninja pkgconf base.gperf ];
    env = { files = ../files/fontconfig; };
  };

  # The fonts, Arabic and Latin from day 0, and which of them the generic
  # names are is files/fontconfig/58-bunix-fonts.conf:
  #   Noto Sans, Noto Serif, Noto Sans Mono   Latin, Greek, Cyrillic
  #   Noto Sans Arabic, Noto Naskh Arabic     Arabic, for sans-serif and serif
  #   Kawkab Mono                             Arabic, for monospace
  #   Noto Kufi Arabic, IBM Plex Sans Arabic, Tajawal
  #                                           Arabic, only by name
  #   Noto Color Emoji
  # The files of the Google Fonts repository, at one commit, each pinned
  # (desktop/fonts.json); Kawkab Mono, which is not in it, from its
  # release's zip (libarchive's bsdtar unpacks it).  All under the SIL
  # Open Font License.
  fonts =
    let
      commit = "2fe1e8c6b137fb13041a7cfca6fdcd8a910ea4dc";
      fetchFont = font: fetch {
        url = "https://raw.githubusercontent.com/google/fonts/${commit}/ofl/${font.family}/"
          + builtins.replaceStrings [ "[" "]" "," ] [ "%5B" "%5D" "%2C" ] font.file;
        # <family>--<file>, which desktop/fonts.sh takes apart
        name = "${font.family}--" + builtins.replaceStrings [ "[" "]" "," ] [ "-" "" "-" ] font.file;
        inherit (font) sha256;
      };
    in
    mkSystemPackage {
      name = "fonts";
      version = builtins.substring 0 7 commit;
      script = ./desktop/fonts.sh;
      buildDepends = [ base.libarchive ];
      env = {
        fonts = map fetchFont (builtins.fromJSON (builtins.readFile ./desktop/fonts.json));
        kawkab_mono = fetch sources.kawkab-mono;
      };
    };

  # HarfBuzz: text shaping, which turns letters into placed glyphs and
  # joins Arabic letters into their connected forms (pango)
  harfbuzz = mkSystemPackage {
    name = "harfbuzz";
    source = sources.harfbuzz;
    script = ./meson.sh;
    depends = [ glibc toolchain.gccLibraries freetype base.glib ];
    buildDepends = [ meson ninja pkgconf ];
    env = { meson_arguments = "-Dfreetype=enabled -Dglib=enabled -Dgobject=disabled -Dcairo=disabled -Dicu=disabled -Dchafa=disabled -Dpng=disabled -Dzlib=disabled -Dintrospection=disabled -Dgpu=disabled -Dgpu_demo=disabled -Dtests=disabled -Ddocs=disabled -Dutilities=disabled"; };
  };

  # GNU FriBidi: Unicode's bidirectional algorithm, which lays Arabic out
  # right to left (pango)
  fribidi = mkSystemPackage {
    name = "fribidi";
    source = sources.fribidi;
    script = ./meson.sh;
    depends = [ glibc ];
    buildDepends = [ meson ninja pkgconf ];
    env = { meson_arguments = "-Ddocs=false -Dbin=false -Dtests=false -Ddeprecated=false"; };
  };

  # cairo: drawing in two dimensions (pango, niri), into pictures in
  # memory, with FreeType's and Fontconfig's fonts; no X11
  cairo = mkSystemPackage {
    name = "cairo";
    source = sources.cairo;
    script = ./meson.sh;
    depends = [ glibc fontconfig freetype base.glib libpng base.pixman base.zlib ];
    buildDepends = [ meson ninja pkgconf ];
    env = { meson_arguments = "-Dfreetype=enabled -Dfontconfig=enabled -Dpng=enabled -Dzlib=enabled -Dglib=enabled -Dxlib=disabled -Dxcb=disabled -Dtee=disabled -Dlzo=disabled -Dspectre=disabled -Dsymbol-lookup=disabled -Ddwrite=disabled -Dtests=disabled"; };
  };

  # Pango: lays out text in any script, right to left too, through
  # HarfBuzz and FriBidi, and draws it with cairo (niri)
  pango = mkSystemPackage {
    name = "pango";
    source = sources.pango;
    script = ./meson.sh;
    depends = [ glibc cairo fontconfig freetype fribidi base.glib harfbuzz ];
    buildDepends = [ meson ninja pkgconf ];
    env = { meson_arguments = "-Dcairo=enabled -Dfontconfig=enabled -Dfreetype=enabled -Dxft=disabled -Dlibthai=disabled -Dintrospection=disabled -Dsysprof=disabled -Dbuild-testsuite=false -Dbuild-examples=false -Ddocumentation=false -Dman-pages=false"; };
  };

  # ---- The compositor ------------------------------------------------------------

  # hwdata: lists of hardware.  Only pnp.ids, the makers of screens by
  # their three letters, which niri's libdisplay-info names screens with
  # when it is built.  For that build alone.
  hwdata = mkSystemPackage {
    name = "hwdata";
    source = sources.hwdata;
    script = ./desktop/hwdata.sh;
    buildDepends = [ pkgconf ];
  };

  # niri: the Wayland compositor.  Windows on a strip that scrolls
  # sideways, a strip a workspace, workspaces one above the other
  # (https://github.com/YaLTeR/niri).  desktop/niri.sh has what of it is
  # built, and its own libdisplay-info.
  # gccLibraries: a Rust program asks for libgcc_s.  bash: niri-session
  # is a script.
  niri = mkSystemPackage {
    name = "niri";
    source = sources.niri;
    script = ./desktop/niri.sh;
    depends = [ glibc toolchain.gccLibraries libinput libxkbcommon seatd libdrm mesa base.pixman pango cairo base.glib base.systemd wayland tools.bash ];
    buildDepends = [ base.rust pkgconf meson ninja hwdata ];
    env = {
      patches = [
        ../files/niri/software-rendering-when-asked.patch
        ../files/niri/render-node-of-the-device.patch
      ];
      libdisplay_info = fetch sources.libdisplay-info;
      # niri's Cargo.lock, as the `cargo2` source of
      # elements/desktop/niri.bst has it
      crates = map (crate: fetch {
        url = "https://static.crates.io/crates/${crate.name}/${crate.name}-${crate.version}.crate";
        inherit (crate) sha256;
      }) (builtins.fromJSON (builtins.readFile ./desktop/niri-crates.json));
      # and the repository two of its crates are in, at the commit its
      # Cargo.lock names (the element's `kind: git` crates)
      smithay = fetch sources.niri-smithay;
      smithay_commit = sources.niri-smithay.version;
    };
  };

  # ---- Qt 6 ---------------------------------------------------------------------

  # The Vulkan API's C headers, and nothing else: Qt declares its Vulkan
  # parts only when they are there, and Quickshell's DMA-BUF buffers use
  # Qt's Vulkan types.  For builds only: bunix has no Vulkan loader.
  vulkan-headers = mkSystemPackage {
    name = "vulkan-headers";
    source = sources.vulkan-headers;
    script = ./cmake.sh;
    buildDepends = [ base.cmake ninja ];
  };

  # libjpeg-turbo: JPEG images, which Qt reads (DMS's wallpapers)
  libjpeg-turbo = mkSystemPackage {
    name = "libjpeg-turbo";
    source = sources.libjpeg-turbo;
    script = ./cmake.sh;
    depends = [ glibc ];
    buildDepends = [ base.cmake ninja ];
    env = { cmake_arguments = "-DENABLE_STATIC=OFF -DWITH_JAVA=OFF"; };
  };

  # Qt 6's base: Core, Gui, DBus, Network, Widgets, OpenGL and the Wayland
  # platform (in qtbase since 6.10): what Quickshell, and so DMS, are
  # built on.  6.12.0 for Quickshell 0.3.2, which uses Qt's private API:
  # the two move together, to a pair a distribution ships.
  #
  # Wayland only: no X11.  No ICU (HarfBuzz shapes text, and Qt's own
  # locale data has Arabic), no SQL, no printing.  Its own PCRE2: Qt needs
  # the 16-bit library, which base's does not build.  Laid out as Debian
  # has it: plugins, QML modules, host tools and mkspecs in
  # /usr/lib/<triplet>/qt6, headers in /usr/include/qt6; Qt's other
  # modules follow from its CMake files.
  qt6-base =
    let qtDir = "lib/${architecture.triplet}/qt6"; in
    mkSystemPackage {
      name = "qt6-base";
      source = sources.qt6-base;
      script = ./cmake.sh;
      depends = [ glibc toolchain.gccLibraries base.zlib base.zstd libpng libjpeg-turbo base.openssl base.glib base.dbus base.systemd freetype fontconfig harfbuzz libdrm mesa wayland libxkbcommon libinput mtdev ];
      buildDepends = [ base.cmake ninja pkgconf vulkan-headers wayland-protocols ];
      env = { cmake_arguments = "-DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF -DINSTALL_LIBDIR=lib/${architecture.triplet} -DINSTALL_ARCHDATADIR=${qtDir} -DINSTALL_BINDIR=${qtDir}/bin -DINSTALL_LIBEXECDIR=${qtDir}/libexec -DINSTALL_MKSPECSDIR=${qtDir}/mkspecs -DINSTALL_INCLUDEDIR=include/qt6 -DINSTALL_DATADIR=share/qt6 -DINSTALL_DOCDIR=share/doc/qt6 -DINSTALL_EXAMPLESDIR=share/doc/qt6/examples -DINSTALL_PUBLICBINDIR=bin -DFEATURE_wayland=ON -DFEATURE_xcb=OFF -DFEATURE_xlib=OFF -DFEATURE_icu=OFF -DFEATURE_sql=OFF -DFEATURE_printsupport=OFF -DFEATURE_gtk3=OFF -DFEATURE_openssl_linked=ON -DFEATURE_system_zlib=ON -DFEATURE_system_png=ON -DFEATURE_system_jpeg=ON -DFEATURE_system_pcre2=OFF -DFEATURE_system_freetype=ON -DFEATURE_system_harfbuzz=ON"; };
    };

  # qsb, which compiles the shaders of Qt Quick and Quickshell while they
  # are built (with its own glslang and SPIRV-Cross).  For builds only.
  qt6-shadertools = mkSystemPackage {
    name = "qt6-shadertools";
    source = sources.qt6-shadertools;
    script = ./cmake.sh;
    depends = [ glibc toolchain.gccLibraries qt6-base ];
    buildDepends = [ base.cmake ninja pkgconf vulkan-headers ];
    env = { cmake_arguments = "-DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF"; };
  };

  # SVG images and icons: most of DMS's icons are SVG
  qt6-svg = mkSystemPackage {
    name = "qt6-svg";
    source = sources.qt6-svg;
    script = ./cmake.sh;
    depends = [ glibc toolchain.gccLibraries qt6-base base.zlib ];
    buildDepends = [ base.cmake ninja pkgconf vulkan-headers ];
    env = { cmake_arguments = "-DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF"; };
  };

  # QML and Qt Quick (Layouts, Shapes, Effects, Controls): the language
  # and scene graph DMS's whole interface is written in.  No precompiled
  # headers: they take more space than the arm64 builder has
  # (tools/nix-builder/lima.yaml), and save only a little time.
  qt6-declarative = mkSystemPackage {
    name = "qt6-declarative";
    source = sources.qt6-declarative;
    script = ./cmake.sh;
    depends = [ glibc toolchain.gccLibraries qt6-base qt6-svg ];
    buildDepends = [ base.cmake ninja pkgconf vulkan-headers qt6-shadertools tools.python ];
    env = { cmake_arguments = "-DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF -DBUILD_WITH_PCH=OFF"; };
  };

  # ---- The shell ------------------------------------------------------------------

  # CLI11: a C++ command-line parser, of headers only: Quickshell's `qs`
  # options.  For builds only.
  cli11 = mkSystemPackage {
    name = "cli11";
    source = sources.cli11;
    script = ./cmake.sh;
    buildDepends = [ base.cmake ninja ];
    env = { cmake_arguments = "-DCLI11_BUILD_TESTS=OFF -DCLI11_BUILD_EXAMPLES=OFF -DCLI11_BUILD_DOCS=OFF"; };
  };

  # jemalloc: the memory allocator Quickshell links, as upstream advises:
  # QML's many small, short-lived objects fragment glibc's heap, and DMS
  # runs for the whole session
  jemalloc = mkSystemPackage {
    name = "jemalloc";
    source = sources.jemalloc;
    script = ./desktop/jemalloc.sh;
    depends = [ glibc toolchain.gccLibraries ];
    # bzip2: its archive is .tar.bz2
    buildDepends = [ base.bzip2 ];
  };

  # Quickshell: a toolkit for desktop shells written in QML (panels,
  # launchers, lock screens as Wayland layer-shell windows), with services
  # for notifications, the system tray, PAM, polkit, greetd, MPRIS and
  # more, PipeWire's among them.  DMS and its login screen are QML that
  # its `qs` runs.  Built for one Qt (qt6-base).  No X11, and no crash
  # handler (it needs cpptrace).  Its QML modules go beside Qt's.
  quickshell = mkSystemPackage {
    name = "quickshell";
    source = sources.quickshell;
    script = ./cmake.sh;
    depends = [ glibc toolchain.gccLibraries qt6-base qt6-declarative qt6-svg jemalloc wayland libdrm mesa pipewire base.linux-pam base.polkit base.glib ];
    buildDepends = [ base.cmake ninja pkgconf qt6-shadertools cli11 vulkan-headers wayland-protocols ];
    env = { cmake_arguments = "-DDISTRIBUTOR=bunix -DGIT_REVISION=v${sources.quickshell.version} -DCRASH_HANDLER=OFF -DX11=OFF -DINSTALL_QML_PREFIX=lib/${architecture.triplet}/qt6/qml"; };
  };

  # Go, as the Go project publishes it: only for building DMS and its
  # login screen, which need 1.27, and not in any image.  Offline: it
  # never fetches modules, nor a newer Go (desktop/go.sh).
  go = mkSystemPackage {
    name = "go";
    source = sources."go-${system}";
    script = ./desktop/go.sh;
    builtElsewhere = true;
  };

  # DMS (Dux Modular Shell): the desktop shell -- bar, launcher,
  # notifications, control centre, lock screen
  # (https://duxlabs.dev/docs/dms).  One Go program, its Quickshell
  # interface (QML) inside it, which it runs with Quickshell's `qs`.  Pure
  # Go, no cgo.  desktop/dms.sh has how it is built offline, and how it
  # comes up with niri.
  dms = mkSystemPackage {
    name = "dms";
    source = sources.dms;
    script = ./desktop/dms.sh;
    depends = [ quickshell ];
    buildDepends = [ go ];
    env = {
      release = sources.dms.version;
      patches = [ ../files/dms/store-text-at-run-time.patch ];
      # a git submodule, so not in the release's archive: the commit the
      # release names
      qml_common = fetch sources.dms-qml-common;
      # the Go modules it is built with, as a module proxy lays them out
      # (desktop/dms-go-modules.json)
      go_modules = goModules ./desktop/dms-go-modules.json;
    };
  };

  # DMS's login screen, a greeter of greetd: it starts niri as the
  # greeter user, and its Quickshell interface in it.  Built as DMS is
  # (desktop/dms-greeter.sh).  accountsservice: its list of users.
  dms-greeter = mkSystemPackage {
    name = "dms-greeter";
    source = sources.dms-greeter;
    script = ./desktop/dms-greeter.sh;
    depends = [ quickshell niri greetd accountsservice ];
    buildDepends = [ go ];
    env = {
      release = sources.dms-greeter.version;
      qml_common = fetch sources.dms-greeter-qml-common;
      go_modules = goModules ./desktop/dms-greeter-go-modules.json;
    };
  };

  # Each of a Go program's modules, as `<where in the proxy>=<file in the
  # store>`, which its script splits at the first "=" to lay them out as
  # a module proxy: the files Go's go.sum describes, fetched one by one.
  goModules = list: map (module:
    "${module.path}=" + fetch {
      url = "https://proxy.golang.org/${module.path}";
      inherit (module) sha256;
    }) (builtins.fromJSON (builtins.readFile list));

  # ---- Sound ---------------------------------------------------------------------

  # alsa-lib: what programs play and record sound with, straight to the
  # kernel's drivers or through PipeWire (its ALSA plugin), and its
  # configuration in /usr/share/alsa (desktop/alsa-lib.sh)
  alsa-lib = mkSystemPackage {
    name = "alsa-lib";
    source = sources.alsa-lib;
    script = ./desktop/alsa-lib.sh;
    depends = [ glibc ];
    buildDepends = [ base.bzip2 ];
  };

  # PipeWire: the desktop's sound server.  It mixes every program's sound
  # onto the card, with a PulseAudio server (pipewire-pulse) for programs
  # written for PulseAudio, and an ALSA plugin that makes it ALSA's
  # default device.  Video streams too, for sharing a screen.  Each
  # person's own service, started with their session.  Quickshell links
  # its library, and DMS's interface will not load without it.  Without
  # Bluetooth, JACK, cameras and real-time priority (its limits belong in
  # /etc/security, which an extension cannot carry); without a session
  # manager, WirePlumber, which routes the sound (step 3 of the port,
  # docs/desktop.md).  desktop/pipewire.sh has what is built.
  pipewire = mkSystemPackage {
    name = "pipewire";
    source = sources.pipewire;
    script = ./desktop/pipewire.sh;
    depends = [ glibc alsa-lib base.dbus base.readline base.systemd ];
    buildDepends = [ meson ninja pkgconf base.gettext base.bzip2 ];
  };

  # Lua 5.5: WirePlumber's policy is written in it.  A shared library and
  # its pkg-config file, which upstream's build does not make; without the
  # lua and luac programs (desktop/lua.sh).
  lua = mkSystemPackage {
    name = "lua";
    source = sources.lua;
    script = ./desktop/lua.sh;
    depends = [ glibc ];
    env = { lua_version = sources.lua.version; };
  };

  # WirePlumber: PipeWire's session manager.  It finds the sound cards,
  # picks the output (the speakers, the headphones once plugged in),
  # remembers volumes, and lets programs in; wpctl sets volumes from the
  # command line.  Started with PipeWire, in each person's session
  # (desktop/wireplumber.sh).
  wireplumber = mkSystemPackage {
    name = "wireplumber";
    source = sources.wireplumber;
    script = ./desktop/wireplumber.sh;
    depends = [ glibc base.glib lua pipewire base.systemd ];
    buildDepends = [ meson ninja pkgconf base.gettext base.bzip2 ];
  };

  # alsa-utils: alsactl, which sets the sound cards' volumes at boot
  # (unmuted, at ALSA's defaults the first time, then as they were left),
  # and amixer, aplay and speaker-test.  Without alsamixer's interface,
  # the BAT tester and the manuals (desktop/alsa-utils.sh).  bash:
  # alsa-info.sh, which gathers what a bug report about sound needs.
  alsa-utils = mkSystemPackage {
    name = "alsa-utils";
    source = sources.alsa-utils;
    script = ./desktop/alsa-utils.sh;
    depends = [ glibc alsa-lib tools.bash ];
    buildDepends = [ pkgconf base.bzip2 ];
  };

  # ---- Logging in -------------------------------------------------------------------

  # greetd: the login manager.  On tty1 it runs the greeter (dms-greeter)
  # as the "greeter" user, checks the name and password the greeter sends
  # with PAM, and starts the person's session as them.  Its
  # configuration is the greeter's, in /usr/share/greetd: an extension
  # has no /etc.  desktop/greetd.sh has its user, PAM files and unit.
  greetd = mkSystemPackage {
    name = "greetd";
    source = sources.greetd;
    script = ./desktop/greetd.sh;
    depends = [ glibc toolchain.gccLibraries base.linux-pam ];
    buildDepends = [ base.rust ];
    env = {
      crates = map (crate: fetch {
        url = "https://static.crates.io/crates/${crate.name}/${crate.name}-${crate.version}.crate";
        inherit (crate) sha256;
      }) (builtins.fromJSON (builtins.readFile ./desktop/greetd-crates.json));
    };
  };

  # AccountsService: a D-Bus service that lists who can log in, with each
  # one's display name, picture and language (org.freedesktop.Accounts).
  # The login screen takes its list of users from it, DMS the name and
  # picture in its bar.  Started at boot, so that the list is ready when
  # the login screen draws (desktop/accountsservice.sh).  Administrators
  # are the wheel group, as for polkit.
  accountsservice = mkSystemPackage {
    name = "accountsservice";
    source = sources.accountsservice;
    script = ./desktop/accountsservice.sh;
    depends = [ glibc base.glib base.polkit base.dbus base.systemd base.libxcrypt ];
    buildDepends = [ meson ninja pkgconf base.gettext ];
    env = { release = sources.accountsservice.version; };
  };

  # The session bus: the D-Bus bus of each logged-in person's own services
  # and programs.  dbus-daemon is the base's, built without these two
  # units, which are made here from the same source and started with the
  # person's session (sockets.target).
  dbus-user-session = mkSystemPackage {
    name = "dbus-user-session";
    source = sources.dbus;
    script = ./desktop/dbus-user-session.sh;
    depends = [ base.dbus ];
  };

in
{
  inherit libdrm wayland wayland-protocols python-mako python-pyyaml spirv-headers spirv-tools spirv-llvm-translator mesa;
  inherit libevdev mtdev libinput seatd xkeyboard-config libxkbcommon;
  inherit libpng freetype fontconfig fonts harfbuzz fribidi cairo pango;
  inherit hwdata niri;
  inherit vulkan-headers libjpeg-turbo qt6-base qt6-shadertools qt6-svg qt6-declarative;
  inherit cli11 jemalloc quickshell go dms dms-greeter greetd accountsservice dbus-user-session;
  inherit alsa-lib pipewire lua wireplumber alsa-utils;
}
