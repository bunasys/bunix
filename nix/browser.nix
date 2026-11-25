# Hudhud, the browser (docs/browser.md), and what only it is built with:
# Chromium's own toolchain pieces and the libraries the system has no
# other use for.  Its packages go into the desktop extension
# (images/desktop.nix) with Hudhud itself, in step 3 of the plan.
# Ported from 0.4.0's elements the way desktop.nix says
# (`git show v0.4.0:elements/base/chromium.bst`).
#
#   nix-build /bunix/nix/browser.nix -A nss
#
# docs/browser.md has the plan and how far it has come.
{ system ? builtins.currentSystem }:

let
  toolchain = import ./toolchain.nix { inherit system; };
  tools = import ./tools.nix { inherit system; };
  base = import ./base.nix { inherit system; };
  desktop = import ./desktop.nix { inherit system; };
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  fetch = import ./fetch.nix;
  inherit (toolchain) glibc;
  inherit (base) meson ninja pkgconf;

  mkSystemPackage = import ./system-package.nix {
    inherit system;
    inherit (tools) buildEnvironment;
    defaultEnv = tools.compilerFlags;
  };

  # ---- Certificates and TLS: NSS --------------------------------------------------

  # NSPR: the portable runtime NSS is written against (threads, sockets,
  # time), Mozilla's.
  nspr = mkSystemPackage {
    name = "nspr";
    source = sources.nspr;
    script = ./browser/nspr.sh;
    depends = [ glibc ];
  };

  # NSS: Mozilla's TLS and certificate libraries, which Chromium keeps a
  # person's certificate databases with (client certificates, ones they
  # trust themselves), beside its own TLS (BoringSSL).
  nss = mkSystemPackage {
    name = "nss";
    source = sources.nss;
    script = ./browser/nss.sh;
    depends = [ glibc nspr base.zlib ];
    # perl: certdata.c, the built-in root certificates, is generated
    buildDepends = [ base.perl ];
  };

  # ---- What Chromium itself links, beside GTK ---------------------------------

  # libxml2: XML, which at-spi2-core reads its interfaces' descriptions in
  libxml2 = mkSystemPackage {
    name = "libxml2";
    source = sources.libxml2;
    script = ./browser/libxml2.sh;
    depends = [ glibc base.zlib ];
    buildDepends = [ pkgconf ];
  };

  # at-spi2-core: accessibility over D-Bus, which Chromium and GTK 4 tell
  # a screen reader what is on the screen through
  at-spi2-core = mkSystemPackage {
    name = "at-spi2-core";
    source = sources.at-spi2-core;
    script = ./meson.sh;
    depends = [ glibc base.dbus base.glib libxml2 base.systemd ];
    buildDepends = [ meson ninja pkgconf ];
    env = { meson_arguments = "-Dx11=disabled -Dintrospection=disabled -Ddocs=false -Duse_systemd=true -Ddefault_bus=dbus-daemon"; };
  };

  # pciutils: libpci, which Chromium's GPU code (ANGLE) reads the GPU's
  # PCI ids with, to know which driver workarounds apply
  pciutils = mkSystemPackage {
    name = "pciutils";
    source = sources.pciutils;
    script = ./browser/pciutils.sh;
    depends = [ glibc base.kmod ];
    buildDepends = [ pkgconf ];
  };

  # ---- GTK 4: Chromium's file dialogs ------------------------------------------
  # Chromium draws its open and save dialogs with GTK 4 (as 0.4.0's did):
  # a portal's would take Nautilus or GTK 3 (docs/browser.md, step 1).

  # libepoxy: finds OpenGL's functions at run time (GTK 4 draws with it)
  libepoxy = mkSystemPackage {
    name = "libepoxy";
    source = sources.libepoxy;
    script = ./meson.sh;
    depends = [ glibc desktop.mesa ];
    buildDepends = [ meson ninja pkgconf ];
    env = { meson_arguments = "-Dglx=no -Degl=yes -Dx11=false -Dtests=false -Ddocs=false"; };
  };

  # graphene: the vector and matrix types GTK 4 lays out and draws with
  graphene = mkSystemPackage {
    name = "graphene";
    source = sources.graphene;
    script = ./meson.sh;
    depends = [ glibc base.glib ];
    buildDepends = [ meson ninja pkgconf ];
    env = { meson_arguments = "-Dgobject_types=true -Dintrospection=disabled -Dtests=false -Dinstalled_tests=false"; };
  };

  # libtiff: TIFF pictures, which GTK 4 reads and writes textures in
  libtiff = mkSystemPackage {
    name = "libtiff";
    source = sources.libtiff;
    script = ./cmake.sh;
    depends = [ glibc desktop.libjpeg-turbo base.zlib ];
    buildDepends = [ base.cmake ninja pkgconf ];
    env = { cmake_arguments = "-Dtiff-tools=OFF -Dtiff-tests=OFF -Dtiff-contrib=OFF -Dtiff-docs=OFF -Dtiff-cxx=OFF -Djbig=OFF -Dlerc=OFF -Dlzma=OFF -Dwebp=OFF -Dzstd=OFF -Dlibdeflate=OFF -Djpeg=ON -Dzlib=ON"; };
  };

  # gdk-pixbuf: pictures (icons in the dialogs), PNG, JPEG and GIF
  gdk-pixbuf = mkSystemPackage {
    name = "gdk-pixbuf";
    source = sources.gdk-pixbuf;
    script = ./meson.sh;
    depends = [ glibc base.glib desktop.libjpeg-turbo desktop.libpng ];
    buildDepends = [ meson ninja pkgconf ];
    # the loaders built in: as modules they would need a loaders.cache,
    # which gdk-pixbuf makes only when installed on a running system
    env = { meson_arguments = "-Dbuiltin_loaders=png,jpeg,gif -Dpng=enabled -Djpeg=enabled -Dtiff=disabled -Dgif=enabled -Dglycin=disabled -Dothers=disabled -Dthumbnailer=disabled -Dgio_sniffing=false -Dintrospection=disabled -Dman=false -Ddocumentation=false -Dtests=false -Dinstalled_tests=false"; };
  };

  # GTK 4 itself, Wayland only (browser/gtk4.sh has what of it is built).
  # Its file dialog reads its settings through GSettings, and GLib stops
  # a program whose schemas are not compiled: the desktop extension
  # compiles the schemas of everything in it (step 3).
  gtk4 = mkSystemPackage {
    name = "gtk4";
    source = sources.gtk4;
    script = ./browser/gtk4.sh;
    depends = [ glibc desktop.cairo desktop.fontconfig desktop.freetype desktop.fribidi gdk-pixbuf base.glib graphene desktop.harfbuzz desktop.libdrm libepoxy desktop.libjpeg-turbo desktop.libpng libtiff desktop.libxkbcommon desktop.mesa desktop.pango desktop.wayland ];
    buildDepends = [ meson ninja pkgconf base.gettext desktop.wayland-protocols ];
  };

  # ---- Chromium's compilers ------------------------------------------------------

  # compiler-rt's builtins and profile runtime, which Chromium links
  # itself: the math functions that must win over Rust's, and what its
  # Rust code is built with.  The system's LLVM (base.llvm) leaves
  # compiler-rt out; this adds it beside that clang, in its resource
  # directory (/usr/lib/<triplet>/clang/23), from the same source, and
  # changes nothing of the system's.  Chromium looks under its
  # clang_base_path's lib/clang/ instead: its build lays out a directory
  # of links in that shape (step 2).
  compiler-rt = mkSystemPackage {
    name = "compiler-rt";
    source = sources.llvm;
    script = ./browser/compiler-rt.sh;
    buildDepends = [ base.llvm base.cmake ninja ];
  };

  # The Rust release before chromium-rust's nightly, which a nightly is
  # built with, as the Rust project publishes it (sources.json has the
  # version).  For that build alone, beside the system's Rust
  # (base.rust), which stays where it is.
  chromium-rust-stage0 = mkSystemPackage {
    name = "chromium-rust-stage0";
    source = sources."chromium-rust-stage0-rustc-${system}";
    script = ./browser/chromium-rust-stage0.sh;
    depends = [ glibc toolchain.gccLibraries toolchain.gcc base.zlib ];
    builtElsewhere = true;
    env = {
      rust_std = fetch sources."chromium-rust-stage0-rust-std-${system}";
      cargo = fetch sources."chromium-rust-stage0-cargo-${system}";
    };
  };

  # Rust as Chromium builds with it, in /usr/lib/chromium-rust: a
  # nightly, the standard library's source (Chromium compiles the
  # standard library itself) and rustc's own crates (rustc-dev), which
  # Crubit's generator is built against.  Parts of Chromium (Blink's
  # fonts, QR codes, CBOR) call Rust through C++ bindings that Crubit
  # makes, and that only works with this layout.
  #
  # The nightly closest after the commit Chromium 158 pins
  # (tools/rust/update_rust.py: 8a9dd7ab, 2026-10-15): 142 commits later,
  # none of which adds or removes a file of the standard library (whose
  # files Chromium lists).  Built against the system's LLVM (base.llvm),
  # the one Chromium's clang is, rather than the LLVM Rust bundles.
  # For the build only; not on a running system.
  chromium-rust = mkSystemPackage {
    name = "chromium-rust";
    source = sources.chromium-rust;
    script = ./browser/chromium-rust.sh;
    # rustc links LLVM statically; LLVM needs zlib and zstd
    depends = [ glibc toolchain.gccLibraries toolchain.gcc base.zlib base.zstd ];
    buildDepends = [ chromium-rust-stage0 base.llvm base.cmake ninja pkgconf ];
  };

  # Crubit's cc_bindings_from_rs, the C++ bindings for Chromium's Rust
  # code, and its support library: installed into chromium-rust's
  # directory, where Chromium looks for them (bin/, and
  # lib/third_party/crubit), as tools/rust/build_crubit.py lays out
  # Chromium's own package.  It runs inside that rustc, so it is built
  # by it.  The revision Chromium 158 pins (tools/rust/update_rust.py).
  # Crubit's other tool, rs_bindings_from_cc, Chromium does not use
  # unless asked (enable_rust_api_from_cpp), and it is not built.
  crubit = mkSystemPackage {
    name = "crubit";
    source = sources.crubit;
    script = ./browser/crubit.sh;
    # librustc_driver, which it loads, is chromium-rust's
    depends = [ glibc toolchain.gccLibraries chromium-rust ];
    # cargo: the system's (base.rust), driving chromium-rust's rustc
    buildDepends = [ base.rust ];
    env = {
      # Crubit's Cargo.lock
      crates = map (crate: fetch {
        url = "https://static.crates.io/crates/${crate.name}/${crate.name}-${crate.version}.crate";
        inherit (crate) sha256;
      }) (builtins.fromJSON (builtins.readFile ./browser/crubit-crates.json));
    };
  };
in
{
  inherit compiler-rt chromium-rust-stage0 chromium-rust crubit;
  inherit nspr nss;
  inherit libxml2 at-spi2-core pciutils libepoxy graphene libtiff gdk-pixbuf gtk4;
}
