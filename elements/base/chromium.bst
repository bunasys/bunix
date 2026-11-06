kind: manual
description: |
  Chromium, built for Buna Browser (base/buna-browser.bst, docs/browser.md):
  Brave Search as the default search engine, Shields' code (files/
  buna-browser/chromium) and Buna's patches (files/buna-browser/patches).
  Wayland only, GTK 4.

  Built from Google's source tarball for distributions, with this
  system's toolchain: clang and lld from LLVM 23 (base/llvm-23.bst), Rust
  and Crubit as Chromium's own package has them (base/chromium-rust.bst,
  base/crubit.bst), Node 24, bindgen, Go (Dawn's generator).  Chromium's
  own copies of its libraries (ICU, FFmpeg, HarfBuzz, ...) stay; it takes
  from the system NSS, GLib, GTK 4, D-Bus, AT-SPI, Fontconfig, Wayland,
  Mesa (GBM and OpenGL's headers), libdrm, xkbcommon, libffi, libpci,
  libudev, ALSA and PipeWire.

  This element is only the long build (hours, on the Fly machine:
  tools/fly/README.md).  Its inputs are kept to what the compiler needs,
  so that a new filter list, policy or icon (base/buna-browser.bst,
  base/buna-shields.bst) does not rebuild it.

  Installs /usr/lib/buna-browser: the browser and the files it loads from
  its own directory.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- base/llvm-23.bst
- base/chromium-rust.bst
- base/crubit.bst
- base/bindgen.bst
- base/nodejs.bst
- base/go.bst
- base/python.bst
- base/ninja.bst
- base/pkgconf.bst
- base/gperf.bst
- base/wayland-protocols.bst

depends:
- base/alsa-lib.bst
- base/at-spi2-core.bst
- base/dbus.bst
- base/fontconfig.bst
- base/glib.bst
- base/gtk4.bst
# use_system_libffi, below
- base/libffi.bst
- base/libdrm.bst
- base/libxkbcommon.bst
- base/mesa.bst
- base/nspr.bst
- base/nss.bst
# ANGLE reads the GPU's PCI ids with it
- base/pciutils.bst
- base/pipewire.bst
- base/systemd.bst
- base/wayland.bst

variables:
  browser-dir: "%{prefix}/lib/buna-browser"
  out: out/Release

environment:
  # gl.pc, made in configure-commands: Mesa installs none without GLX
  PKG_CONFIG_PATH: "%{build-root}/pkgconfig-shims"
  # Go (Dawn's generator) keeps its build cache in the build tree; base/
  # go.bst keeps it offline
  GOCACHE: "%{build-root}/go-cache"

config:
  configure-commands:
  - |
    # WebRTC's screen capture asks pkg-config for OpenGL's headers (only
    # the headers).  Mesa installs them, but its gl.pc comes with GLX,
    # which the system leaves out (Wayland only).
    mkdir -p pkgconfig-shims
    cat > pkgconfig-shims/gl.pc <<PC
    Name: gl
    Description: OpenGL headers (Mesa)
    Version: $(pkg-config --modversion egl)
    Cflags:
    PC
    pkg-config --cflags gl

  - |
    # Shields' code, and the interface of the engine it loads
    # (base/buna-shields.bst)
    cp -r buna/chromium/. .
    cp buna/shields-include/buna_shields.h chrome/browser/buna_shields/buna_shields.h

  # Brave Search: the default search engine in every country
  - python3 buna/scripts/brave-search-first.py .

  - |
    # Node.js: where Chromium's build looks for its own copy, and the
    # version it checks for set to the system's (Node 24, as Chromium's)
    mkdir -p third_party/node/linux/node-linux-x64/bin
    ln -sf %{bindir}/node third_party/node/linux/node-linux-x64/bin/node
    sed -i "s/^NODE_VERSION=.*/NODE_VERSION=\"$(node --version)\"/" third_party/node/update_node_binaries

  - |
    # Go: where Dawn looks for its own copy (third_party/dawn/tools/
    # generate-sources-gn.py)
    mkdir -p third_party/dawn/tools/golang
    ln -sfn %{prefix}/lib/go third_party/dawn/tools/golang/linux-amd64

  # Rust: Chromium's own layout (base/chromium-rust.bst, base/crubit.bst)
  - ln -sfn %{prefix}/lib/chromium-rust third_party/rust-toolchain

  - |
    # bindgen's tools, laid out as Chromium expects them: bindgen, LLVM 23's
    # libclang, and rustfmt (Chromium's Rust's)
    mkdir -p bindgen-root/bin
    ln -sf %{bindir}/bindgen bindgen-root/bin/bindgen
    ln -sfn /usr/lib/llvm-23/lib bindgen-root/lib
    ln -sf %{prefix}/lib/chromium-rust/bin/rustfmt bindgen-root/bin/rustfmt

  # gn, Chromium's build file generator, from its own source in the tarball;
  # its bootstrap looks for clang on PATH, where LLVM 23's is not
  - |
    CC=/usr/lib/llvm-23/bin/clang CXX=/usr/lib/llvm-23/bin/clang++ AR=/usr/lib/llvm-23/bin/llvm-ar \
      python3 tools/gn/bootstrap/bootstrap.py --skip-generate-buildfiles --build-path=%{out}

  - |
    # Official build: optimized, no debug symbols, no ThinLTO or CFI (they
    # need much more memory and time).  Wayland only; GTK 4; ALSA (PipeWire
    # is ALSA's default device); PipeWire for screen sharing.  No CUPS,
    # Kerberos, Qt, VA-API, VR headsets, Widevine or Google API keys.
    # H.264 and AAC.
    cat > %{out}/args.gn <<ARGS
    is_official_build = true
    is_debug = false
    symbol_level = 0
    blink_symbol_level = 0
    v8_symbol_level = 0
    chrome_pgo_phase = 0
    use_thin_lto = false
    is_cfi = false
    treat_warnings_as_errors = false
    fatal_linker_warnings = false
    use_sysroot = false
    # the system's libffi (Wayland's and GLib's), not a static one from
    # Google's sysroot
    use_system_libffi = true
    use_siso = false

    is_clang = true
    clang_base_path = "/usr/lib/llvm-23"
    clang_version = "23"
    clang_use_chrome_plugins = false
    use_lld = true
    rust_bindgen_root = "$PWD/bindgen-root"

    ozone_auto_platforms = false
    ozone_platform = "wayland"
    ozone_platform_wayland = true
    ozone_platform_x11 = false
    ozone_platform_headless = true
    use_gtk = true
    gtk_version = 4
    use_qt5 = false
    use_qt6 = false

    use_cups = false
    use_kerberos = false
    use_pulseaudio = false
    use_vaapi = false
    rtc_use_pipewire = true
    rtc_link_pipewire = false
    enable_widevine = false
    enable_hangout_services_extension = false
    enable_remoting = false
    # VR headsets (OpenXR): not a goal on a touch tablet, and its loader
    # wants Vulkan's headers from the system
    enable_openxr = false

    proprietary_codecs = true
    ffmpeg_branding = "Chrome"
    ARGS
    cat %{out}/args.gn
    %{out}/gn gen %{out} --fail-on-unused-args

  build-commands:
  # Built on the Fly machine's 16 CPUs (tools/fly/README.md)
  - ninja -C %{out} -j16 chrome

  install-commands:
  - |
    dir=%{install-root}%{browser-dir}
    mkdir -p $dir/locales
    cp %{out}/chrome $dir/buna-browser
    cp %{out}/chrome_crashpad_handler \
       %{out}/chrome_100_percent.pak %{out}/chrome_200_percent.pak %{out}/resources.pak \
       %{out}/icudtl.dat %{out}/v8_context_snapshot.bin \
       %{out}/libEGL.so %{out}/libGLESv2.so \
       %{out}/libvk_swiftshader.so %{out}/vk_swiftshader_icd.json %{out}/libvulkan.so.1 \
       $dir/
    # Arabic and English, as the rest of the system (system/rootfs.bst)
    cp %{out}/locales/en-US.pak %{out}/locales/ar.pak $dir/locales/
    strip --strip-unneeded $dir/buna-browser $dir/chrome_crashpad_handler
    du -sh $dir

sources:
- kind: tar
  url: chromium:chromium-157.0.8103.38-lite.tar.xz
  ref: 6f7f34ef0f249374ee959c701a139e5d19860c1c02bc2e04f010e437cc744863
- kind: local
  path: files/buna-browser/chromium
  directory: buna/chromium
- kind: local
  path: files/buna-browser/scripts
  directory: buna/scripts
- kind: local
  path: files/buna-browser/shields/include
  directory: buna/shields-include
- kind: patch
  path: files/buna-browser/patches/01-shields-network.patch
- kind: patch
  path: files/buna-browser/patches/02-shields-tab-helper.patch
- kind: patch
  path: files/buna-browser/patches/03-shields-build.patch
- kind: patch
  path: files/buna-browser/patches/04-shields-page-info-switch.patch
- kind: patch
  path: files/buna-browser/patches/05-policy-path.patch
- kind: patch
  path: files/buna-browser/patches/06-profile-directory.patch
- kind: patch
  path: files/buna-browser/patches/07-no-api-keys-infobar.patch
