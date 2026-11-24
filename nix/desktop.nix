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
  mesa = mkSystemPackage {
    name = "mesa";
    source = sources.mesa;
    script = ./desktop/mesa.sh;
    depends = [ glibc toolchain.gccLibraries base.elfutils libdrm wayland base.expat base.zlib base.zstd ];
    # python-ctypes: a generator of the Intel compiler's tables imports it
    buildDepends = [ meson ninja pkgconf base.flex python-mako python-pyyaml base.python-packaging base.python-ctypes wayland-protocols base.llvm spirv-headers spirv-tools spirv-llvm-translator ];
    env = {
      patches = [ ../files/mesa/radeonsi-without-llvm-amdgpu.patch ];
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

in
{
  inherit libdrm wayland wayland-protocols python-mako python-pyyaml spirv-headers spirv-tools spirv-llvm-translator mesa;
  inherit libevdev mtdev libinput seatd xkeyboard-config libxkbcommon;
  inherit libpng freetype fontconfig harfbuzz fribidi cairo pango;
  inherit hwdata niri;
}
