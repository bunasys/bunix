unpack $src
out_dir=out/Release
browser_dir=/usr/lib/hudhud

# ---- The source: ungoogled-chromium, then Hudhud -------------------------------

unpack $ungoogled ungoogled
# Hudhud's parts, laid out as files/hudhud has them (prepare-source.sh)
mkdir -p hudhud/shields
cp -r $hudhud_chromium hudhud/chromium
cp -r $hudhud_scripts hudhud/scripts
cp -r $hudhud_patches hudhud/patches
cp -r $hudhud_ungoogled hudhud/ungoogled
cp -r $hudhud_shields_include hudhud/shields/include
chmod -R u+w hudhud
# ungoogled-chromium's pruning and patches, then Hudhud's code and
# patches, Brave Search first, its name in the strings, Google's
# addresses replaced: the same steps as on macOS (tools/build-macos.sh)
sh hudhud/scripts/prepare-source.sh "$PWD" "$PWD/ungoogled" "$PWD/hudhud"

# ---- Chromium's prebuilt tools, from this system -------------------------------
# Chromium fetches these prebuilt from Google's CIPD; ungoogled-chromium
# prunes them.  Each goes where Chromium's build looks for its own.

# TypeScript (tsgo, Chromium's own pages) and esbuild (DevTools' bundler),
# at the versions Chromium pins, with the change Chromium makes to
# TypeScript's DOM types (microsoft/TypeScript#30024).  tsgo.gni looks in
# linux-amd64/ on any Linux machine.
tsgo=third_party/typescript/linux-amd64/src
unpack $typescript $tsgo
patch --silent $tsgo/lib/lib.dom.d.ts < third_party/node/patches/typescript.patch
esbuild=third_party/devtools-frontend/src/third_party/esbuild
unpack $esbuild_package esbuild-package
mkdir -p $esbuild
install -m 755 esbuild-package/bin/esbuild $esbuild/esbuild

# Node.js: node.py and node.gni name the x64 directory on any Linux
# machine.  The version Chromium checks for is set to the system's.
mkdir -p third_party/node/linux/node-linux-x64/bin
ln -sf /usr/bin/node third_party/node/linux/node-linux-x64/bin/node
sed -i "s/^NODE_VERSION=.*/NODE_VERSION=\"$(node --version)\"/" third_party/node/update_node_binaries

# Go, which Dawn's generator runs: in tools/golang/<CIPD platform>
case $triplet in
    x86_64-*) cipd_platform=linux-amd64 ;;
    aarch64-*) cipd_platform=linux-arm64 ;;
    *) echo "chromium.sh: no Go platform for $triplet" >&2; exit 1 ;;
esac
mkdir -p third_party/dawn/tools/golang
ln -sfn /usr/lib/go third_party/dawn/tools/golang/$cipd_platform
export GOCACHE=$PWD/go-cache

# gperf (Blink's lookup tables) and clang-format (Crubit formats the
# bindings it makes)
mkdir -p third_party/gperf/cipd/bin buildtools/linux64-format
ln -sf /usr/bin/gperf third_party/gperf/cipd/bin/gperf
ln -sf /usr/bin/clang-format buildtools/linux64-format/clang-format

# Rust: Chromium's own toolchain layout (chromium-rust, crubit)
ln -sfn /usr/lib/chromium-rust third_party/rust-toolchain

# clang as Chromium expects its own: programs in bin/, the runtime
# (compiler-rt) in lib/clang/<version>/lib/<target>/.  bunix's LLVM has its
# resource directory under /usr/lib/<triplet>/, and clang finds it from
# the path it was started by (Chromium's -no-canonical-prefixes): it is
# here under both names.
clang_version=$(llvm-config --version | cut -d. -f1)
mkdir -p clang-root/lib
ln -sfn /usr/bin clang-root/bin
ln -sfn /usr/lib/$triplet/clang clang-root/lib/clang
ln -sfn /usr/lib/$triplet clang-root/lib/$triplet

# bindgen's tools as Chromium expects them: bindgen and rustfmt in bin/,
# libclang in lib/
mkdir -p bindgen-root/bin
ln -sf /usr/bin/bindgen bindgen-root/bin/bindgen
ln -sf /usr/lib/chromium-rust/bin/rustfmt bindgen-root/bin/rustfmt
ln -sfn /usr/lib/$triplet bindgen-root/lib

# WebRTC's screen capture asks pkg-config for OpenGL's headers (only the
# headers).  Mesa installs them, but its gl.pc comes with GLX, which the
# system leaves out (Wayland only).
mkdir -p pkgconfig-shims
cat > pkgconfig-shims/gl.pc <<PC
Name: gl
Description: OpenGL headers (Mesa)
Version: $(pkg-config --modversion egl)
Cflags:
PC
export PKG_CONFIG_PATH=$PWD/pkgconfig-shims

# ---- The compiler cache, where the builder gives one ------------------------
# A builder that keeps a cache of compiles gives builds this directory
# (docs/browser.md, "The compiler cache"); without it, everything is
# compiled.  Under /dev: the one directory stage.sh takes whole, with what
# is mounted in it, into the root the build runs in.
compiler_cache=/dev/ccache
use_ccache=no
if [ -w $compiler_cache ]; then
    use_ccache=yes
fi
if [ $use_ccache = yes ]; then
    export CCACHE_DIR=$compiler_cache
    # The compiler is LLVM's libraries more than /usr/bin/clang, a small
    # driver: compiles are keyed by the store path of LLVM's package,
    # which any change to how LLVM is built changes
    export CCACHE_COMPILERCHECK=string:$llvm_package
    # Shared by the builder's build users
    export CCACHE_UMASK=002
    # A whole build's compiles are about 4 GB: room for two versions
    export CCACHE_MAXSIZE=10G
    # Every file's time in a build is the unpacking's: never part of a key,
    # or a header generated the second a compile starts is never cached
    export CCACHE_SLOPPINESS=include_file_mtime,include_file_ctime,time_macros
    ccache --zero-stats > /dev/null
fi

# ---- Configure and build ---------------------------------------------------------

# gn, Chromium's build file generator, from its own source in the tarball
CC=clang CXX=clang++ AR=llvm-ar python3 tools/gn/bootstrap/bootstrap.py \
    --skip-generate-buildfiles --build-path=$out_dir

# Official build: optimized, no debug symbols, no ThinLTO or CFI (they
# need much more memory and time).  Wayland only; GTK 4 (file dialogs);
# ALSA (PipeWire is ALSA's default device); PipeWire for screen sharing.
# No CUPS, Kerberos, Qt, VA-API, VR headsets, Widevine or Google API
# keys.  H.264 and AAC.  These come after ungoogled-chromium's arguments
# (ungoogled/flags.gn) and win where both set one.
# concurrent_links: a link of the browser takes several GB; more than one
# at a time ran out of memory.
cat > $out_dir/hudhud-args.gn <<ARGS
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
use_system_libffi = true
use_siso = false
concurrent_links = 1

is_clang = true
clang_base_path = "$PWD/clang-root"
clang_version = "$clang_version"
clang_use_chrome_plugins = false
use_lld = true
rust_bindgen_root = "$PWD/bindgen-root"
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
enable_openxr = false

proprietary_codecs = true
ffmpeg_branding = "Chrome"
ARGS
if [ $use_ccache = yes ]; then
    echo 'cc_wrapper = "ccache"' >> $out_dir/hudhud-args.gn
fi
sh hudhud/scripts/merge-gn-args.sh ungoogled/flags.gn $out_dir/hudhud-args.gn > $out_dir/args.gn
cat $out_dir/args.gn
$out_dir/gn gen $out_dir --fail-on-unused-args

# -k 0: on an error, everything that does not need what failed is built
# still, so that one build of hours shows all of its errors, not the first
ninja -C $out_dir -j$jobs -k 0 chrome
[ $use_ccache = no ] || ccache --show-stats

# ---- Install: /usr/lib/hudhud ------------------------------------------------------

dir=$out$browser_dir
mkdir -p $dir/locales
cp $out_dir/chrome $dir/hudhud
cp $out_dir/chrome_crashpad_handler \
   $out_dir/chrome_100_percent.pak $out_dir/chrome_200_percent.pak $out_dir/resources.pak \
   $out_dir/icudtl.dat $out_dir/v8_context_snapshot.bin \
   $out_dir/libEGL.so $out_dir/libGLESv2.so \
   $dir/
# SwiftShader, Vulkan in software (WebGL where the GPU has no driver),
# where Chromium builds it
for file in libvk_swiftshader.so vk_swiftshader_icd.json libvulkan.so.1; do
    [ ! -e $out_dir/$file ] || cp $out_dir/$file $dir/
done
# Arabic and English, as the rest of the system
cp $out_dir/locales/en-US.pak $out_dir/locales/ar.pak $dir/locales/
du -sh $dir
