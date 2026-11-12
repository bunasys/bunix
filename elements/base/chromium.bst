kind: manual
description: |
  Chromium, built for Hudhud (base/hudhud.bst, docs/browser.md):
  ungoogled-chromium's patches and lists, then Hudhud's code and patches
  (files/hudhud), prepared as on macOS by files/hudhud/scripts/
  prepare-source.sh.  Brave Search as the default search engine.
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
  so that a new filter list, policy or icon (base/hudhud.bst,
  base/hudhud-shields.bst) does not rebuild it.

  Installs /usr/lib/hudhud: the browser and the files it loads from
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
# applies ungoogled-chromium's patches and Hudhud's (prepare-source.sh)
- base/patch.bst

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
  browser-dir: "%{prefix}/lib/hudhud"
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

  # ungoogled-chromium, then Hudhud: its code, its patches, Brave Search
  # first, its name in the strings, Google's addresses replaced -- the same
  # steps as on macOS (tools/build-macos.sh)
  - sh hudhud/scripts/prepare-source.sh "$PWD" "$PWD/ungoogled" "$PWD/hudhud"

  - |
    # TypeScript (tsgo, for Chromium's own pages) and esbuild (DevTools'
    # bundler): build tools Chromium ships prebuilt from Google's CIPD, which
    # ungoogled-chromium prunes; the same programs at the versions Chromium
    # pins, from npm, with the change Chromium makes to TypeScript's DOM
    # types (microsoft/TypeScript#30024).  Staged outside the tree, as the
    # pruning would remove them.
    tsgo=third_party/typescript/linux-amd64/src
    mkdir -p $tsgo
    cp -r hudhud-tools/typescript/. $tsgo/
    patch --silent $tsgo/lib/lib.dom.d.ts < third_party/node/patches/typescript.patch
    esbuild=third_party/devtools-frontend/src/third_party/esbuild
    mkdir -p $esbuild
    install -m 755 hudhud-tools/esbuild/bin/esbuild $esbuild/esbuild

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

  - |
    # gperf (Blink's generated lookup tables) and clang-format (Crubit
    # formats the bindings it generates): where Chromium looks for its own
    # prebuilt copies, which ungoogled-chromium prunes
    mkdir -p third_party/gperf/cipd/bin buildtools/linux64-format
    ln -sf %{bindir}/gperf third_party/gperf/cipd/bin/gperf
    ln -sf /usr/lib/llvm-23/bin/clang-format buildtools/linux64-format/clang-format

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
    # H.264 and AAC.  These come after ungoogled-chromium's arguments
    # (ungoogled/flags.gn) and win where both set one.
    cat > %{out}/hudhud-args.gn <<ARGS
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
    # V8's instance types from Torque, its older generator: metagen needs
    # Google's prebuilt libclang package (third_party/llvm-libclang), which
    # ungoogled-chromium prunes
    v8_use_metagen = false

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
    sh hudhud/scripts/merge-gn-args.sh ungoogled/flags.gn %{out}/hudhud-args.gn > %{out}/args.gn
    cat %{out}/args.gn
    %{out}/gn gen %{out} --fail-on-unused-args

  build-commands:
  # Built on the Fly machine's 16 CPUs (tools/fly/README.md)
  - ninja -C %{out} -j16 chrome

  install-commands:
  - |
    dir=%{install-root}%{browser-dir}
    mkdir -p $dir/locales
    cp %{out}/chrome $dir/hudhud
    cp %{out}/chrome_crashpad_handler \
       %{out}/chrome_100_percent.pak %{out}/chrome_200_percent.pak %{out}/resources.pak \
       %{out}/icudtl.dat %{out}/v8_context_snapshot.bin \
       %{out}/libEGL.so %{out}/libGLESv2.so \
       %{out}/libvk_swiftshader.so %{out}/vk_swiftshader_icd.json %{out}/libvulkan.so.1 \
       $dir/
    # Arabic and English, as the rest of the system (system/rootfs.bst)
    cp %{out}/locales/en-US.pak %{out}/locales/ar.pak $dir/locales/
    strip --strip-unneeded $dir/hudhud $dir/chrome_crashpad_handler
    du -sh $dir

sources:
- kind: tar
  url: chromium:chromium-157.0.8103.78-lite.tar.xz
  ref: 9fdce9d3c866f97f14f7a4250915e8e5b729dc952fcfb3a35507b126233f0660
# ungoogled-chromium 157.0.8103.50-1: its patches and lists, checked against
# this Chromium (docs/chromium/157.0.8103.78.md)
- kind: tar
  url: github:ungoogled-software/ungoogled-chromium/archive/f5d393f22a60fa4f79f42dbb26acd0bcc01995ae.tar.gz
  ref: 53680488c4de6371323f001c2da01af38f283e13360bf891e17e32a47b1075ff
  directory: ungoogled
# TypeScript 7.0.2 (tsgo) and esbuild 0.28.2, as Chromium 157 pins them
# (DEPS), in place of the pruned prebuilt copies (configure-commands)
- kind: tar
  url: npm:@typescript/typescript-linux-x64/-/typescript-linux-x64-7.0.2.tgz
  ref: 7ecad6f67377e831856367ab062ef394f21506a611405bf8ac0ff039348637d3
  directory: hudhud-tools/typescript
- kind: tar
  url: npm:@esbuild/linux-x64/-/linux-x64-0.28.2.tgz
  ref: 9573bb2233aab0f9ea7647d5cca9726113cc1768de61d66b17267f4db84488f6
  directory: hudhud-tools/esbuild
# Hudhud, laid out as in files/hudhud (prepare-source.sh)
- kind: local
  path: files/hudhud/chromium
  directory: hudhud/chromium
- kind: local
  path: files/hudhud/scripts
  directory: hudhud/scripts
- kind: local
  path: files/hudhud/shields/include
  directory: hudhud/shields/include
- kind: local
  path: files/hudhud/patches
  directory: hudhud/patches
- kind: local
  path: files/hudhud/ungoogled
  directory: hudhud/ungoogled
