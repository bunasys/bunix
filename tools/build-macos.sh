#!/bin/bash
# Build Hudhud for macOS on Apple Silicon (docs/browser.md, "macOS"):
# ungoogled-chromium with Hudhud's changes, in a .dmg signed with a
# Developer ID (and notarized) or ad hoc.
#
#   tools/build-macos.sh            # every step, in order
#   tools/build-macos.sh <step>     # fetch, source, toolchain, configure,
#                                   # build, shields or package
#   HUDHUD_MACOS_WORK=/Volumes/ssd/hudhud tools/build-macos.sh   # the work tree
#   HUDHUD_MACOS_JOBS=6 tools/build-macos.sh build             # ninja's jobs
#   HUDHUD_MACOS_SDK=/path/to/MacOSX26.x.sdk tools/build-macos.sh  # the SDK
#   HUDHUD_MACOS_SIGN_IDENTITY="Developer ID Application: ..." \
#     tools/build-macos.sh package     # signed with a certificate (security
#                                      # find-identity -v -p codesigning)
#   HUDHUD_MACOS_PROVISIONING_PROFILE=hudhud.provisionprofile ...
#                                      # and its Developer ID profile, for
#                                      # Touch ID passkeys
#
# A newly imported signing key must be opened to codesign once, or signing
# over SSH waits for a dialog on the Mac's screen that nobody can click:
#   security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
#     -k <login password> ~/Library/Keychains/login.keychain-db
#
# Not Nix: it builds in a Linux sandbox, and a macOS app needs Apple's SDK
# from the Xcode installed here.  The sources are pinned all the same:
# Chromium's tarball, ungoogled-chromium, Rust's library source, Crubit,
# bindgen's version and the filter lists are read from nix/sources.json,
# which Linux builds with; everything else is pinned below.
#
# Needs: Xcode with its Metal toolchain, and from Homebrew: python@3.13,
# ninja, go, esbuild, node, coreutils (`brew install ...`).
set -euo pipefail
# a pattern that matches no file expands to nothing
shopt -s nullglob

# Paths given relative to where the script is run from: the steps change
# directory
absolute() {
  case $1 in
    /*) echo "$1" ;;
    *) echo "$PWD/$1" ;;
  esac
}

repo=$(cd "$(dirname "$0")/.." && pwd)
work=$(absolute "${HUDHUD_MACOS_WORK:-$(dirname "$repo")/build-macos}")
jobs=${HUDHUD_MACOS_JOBS:-8}
# macOS 26's SDK, as ungoogled-chromium-macos builds with: 27's lists an
# arm64e.x1 architecture that LLVM 23's linker cannot read.  Command Line
# Tools for Xcode 27 still include it.
sdk=$(absolute "${HUDHUD_MACOS_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}")
# The certificate the app is signed with; "-" signs ad hoc (sign_app says
# what that leaves out)
identity=${HUDHUD_MACOS_SIGN_IDENTITY:--}
# The Developer ID provisioning profile of com.bunasys.hudhud: it allows the
# keychain group Touch ID passkeys are kept in (files/hudhud/macos/
# entitlements); without one the app is signed without that group
profile=${HUDHUD_MACOS_PROVISIONING_PROFILE:-}
if [ -n "$profile" ]; then
  profile=$(absolute "$profile")
fi
# The profile's entitlements only hold with its team's signature: signed ad
# hoc, macOS would refuse to start the app
if [ -n "$profile" ] && [ "$identity" = - ]; then
  echo "HUDHUD_MACOS_PROVISIONING_PROFILE needs HUDHUD_MACOS_SIGN_IDENTITY" >&2
  exit 2
fi
cache=$work/download_cache
src=$work/src
out=$src/out/Default

sources=$repo/nix/sources.json

# ungoogled-chromium's macOS packaging.  At 157, a release behind the
# Chromium Linux builds (it has none for 158): what 158 needs is in
# files/hudhud/macos/patches and files/hudhud/ungoogled/patches, and the
# patches it has that are not used here are listed in MACOS_PATCHES_NOT_USED.
UNGOOGLED_MACOS_TAG=157.0.8103.78-1.1
UNGOOGLED_MACOS_COMMIT=84768e74ece113d9e68e5d774808afe6c3a8fbe6
ungoogled_macos=$work/ungoogled-macos-$UNGOOGLED_MACOS_TAG

# ungoogled-chromium-macos's patches this build does without, and why
MACOS_PATCHES_NOT_USED=(
  # bindgen is built here with cargo, as nix/base.nix builds it
  build-bindgen
  build-bindgen-target-override
  bindgen-disable-static
  # Rust is laid out as Chromium's own package has it (the toolchain step),
  # so Chromium uses it as its own, Crubit included: these make it a
  # foreign toolchain and build without Crubit
  fix-build-with-rust
  fix-build-without-crubit
  # TypeScript: Chromium's pinned tsgo, from npm, instead of Homebrew's tsc
  fix-typescript
  # clang-format is optional: generated code is left unformatted
  fix-clang-format-path
  # in files/hudhud/ungoogled/patches, for Linux too
  use-system-python
  # ported to 157 and 158: files/hudhud/macos/patches/
  # 01-disable-crashpad-handler, and (needed on Linux too)
  # files/hudhud/ungoogled/patches/
  # 01-without-safe-browsing-and-verification-tokens
  disable-crashpad-handler
  fix-disabling-safebrowsing
)

# TypeScript 7 (tsgo) as Chromium 158 pins it (DEPS: typescript/mac-arm64
# version:2@7.0.2), from Microsoft's npm package
TSGO_URL=https://registry.npmjs.org/@typescript/typescript-darwin-arm64/-/typescript-darwin-arm64-7.0.2.tgz
TSGO_SHA256=902e2fe1cf0799198ef902c6b8c310a450fef629a6baba41d45641ef75c04ebd

# The Rust nightly whose source Linux builds Chromium's Rust from
# (chromium-rust in sources.json), prebuilt for macOS, and its rustc's own
# crates (rustc-dev), for Crubit.  The fetch step checks the date is still
# Linux's.
RUST_NIGHTLY=2026-10-16
RUST_URL=https://static.rust-lang.org/dist/$RUST_NIGHTLY/rust-nightly-aarch64-apple-darwin.tar.xz
RUST_SHA256=0ce659d65f86e85f2722e489a9625a6a7af9c7981cc3c099398c8d34ea7c2526
RUSTC_DEV_URL=https://static.rust-lang.org/dist/$RUST_NIGHTLY/rustc-dev-nightly-aarch64-apple-darwin.tar.xz
RUSTC_DEV_SHA256=c0103c37c625b7f96314349ad89112b3b977e56b48b12bf5ce98751cd3023ddc

# ungoogled-chromium's tools want Python 3.13 or older; so do Chromium's
# build scripts, which run as python3 from PATH
use_python313() {
  local python313
  python313=$(command -v python3.13) || {
    echo "Needs Python 3.13: brew install python@3.13" >&2
    exit 1
  }
  mkdir -p "$work/bin"
  ln -sf "$python313" "$work/bin/python3"
  export PATH="$work/bin:$PATH"
}

# One field of a source in nix/sources.json:  pinned <source> url|sha256|version
pinned() {
  python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))[sys.argv[2]][sys.argv[3]])' \
    "$sources" "$1" "$2"
}

# Download a source as sources.json pins it, into the cache as <file>
download_pinned() {
  download "$(pinned "$1" url)" "$(pinned "$1" sha256)" "$2"
}

# Download once into the cache, and check the file every time
download() {
  local url=$1 sha256=$2 file=$cache/$3
  if [ ! -f "$file" ]; then
    curl -fL --retry 3 -o "$file.part" "$url"
    mv "$file.part" "$file"
  fi
  if ! echo "$sha256  $file" | shasum -a 256 -c - > /dev/null; then
    echo "$file: wrong sha256 (expected $sha256); remove it to download again" >&2
    exit 1
  fi
}

# A git repository at a tag, checked against the commit pinned for it
clone_pinned() {
  local url=$1 tag=$2 commit=$3 dir=$work/$4
  if [ ! -d "$dir" ]; then
    git clone --quiet --depth 1 --branch "$tag" "$url" "$dir"
  fi
  if [ "$(git -C "$dir" rev-parse HEAD)" != "$commit" ]; then
    echo "$dir: $tag is not commit $commit" >&2
    exit 1
  fi
}

chromium_version() {
  pinned chromium version
}

# ungoogled-chromium for that Chromium, unpacked by the fetch step
ungoogled_dir() {
  echo "$work/ungoogled-$(pinned ungoogled-chromium version)"
}

step_fetch() {
  mkdir -p "$cache"
  clone_pinned https://github.com/ungoogled-software/ungoogled-chromium-macos.git \
    "$UNGOOGLED_MACOS_TAG" "$UNGOOGLED_MACOS_COMMIT" "$(basename "$ungoogled_macos")"

  local version
  version=$(chromium_version)
  # ungoogled-chromium may be a release behind Chromium: Hudhud moves to a
  # Chromium only once tools/chromium-update.py's report on it is reviewed
  if [ ! -f "$repo/docs/chromium/$version.md" ]; then
    echo "No reviewed report for Chromium $version: run tools/chromium-update.py into docs/chromium/$version.md" >&2
    exit 1
  fi
  # The prebuilt nightly is pinned here by hand: it must be the one whose
  # source Linux builds
  local linux_nightly
  linux_nightly=$(pinned chromium-rust version)
  if [ "nightly-$RUST_NIGHTLY" != "$linux_nightly" ]; then
    echo "RUST_NIGHTLY is $RUST_NIGHTLY, Linux builds $linux_nightly: update RUST_* to its date" >&2
    exit 1
  fi

  download_pinned chromium "chromium-$version-lite.tar.xz"
  download_pinned ungoogled-chromium "ungoogled-chromium-$(pinned ungoogled-chromium version).tar.gz"
  download_pinned chromium-rust "rustc-$linux_nightly-src.tar.xz"
  download_pinned crubit "crubit-$(pinned crubit version).tar.gz"
  download_pinned ublock-assets "uAssets-$(pinned ublock-assets version).tar.gz"
  download_pinned liste-ar "listear-$(pinned liste-ar version).tar.gz"
  download "$TSGO_URL" "$TSGO_SHA256" tsgo.tgz
  download "$RUST_URL" "$RUST_SHA256" "rust-nightly-$RUST_NIGHTLY.tar.xz"
  download "$RUSTC_DEV_URL" "$RUSTC_DEV_SHA256" "rustc-dev-nightly-$RUST_NIGHTLY.tar.xz"

  local ungoogled
  ungoogled=$(ungoogled_dir)
  # Unpacked beside it first, so a stopped unpacking is not taken for one
  if [ ! -d "$ungoogled" ]; then
    rm -rf "$ungoogled.part"
    mkdir -p "$ungoogled.part"
    tar -xzf "$cache/ungoogled-chromium-$(pinned ungoogled-chromium version).tar.gz" \
      -C "$ungoogled.part" --strip-components 1
    mv "$ungoogled.part" "$ungoogled"
  fi

  # LLVM and Node.js, pinned by sha512 in ungoogled-chromium-macos's list
  python3 "$ungoogled/utils/downloads.py" retrieve -c "$cache" \
    -i "$ungoogled_macos/downloads-arm64.ini" --components llvm nodejs
}

step_source() {
  local version ungoogled
  version=$(chromium_version)
  ungoogled=$(ungoogled_dir)
  rm -rf "$src"
  mkdir -p "$src"
  echo "Unpacking Chromium $version ..."
  tar -xJf "$cache/chromium-$version-lite.tar.xz" -C "$src" --strip-components 1

  # The platform's patches go in after ungoogled-chromium's and before
  # Hudhud's (prepare-source.sh): ungoogled-chromium-macos's, but those this
  # build does without, then Hudhud's macOS ones
  local platform_patches=() patch name
  while read -r patch; do
    [ -n "$patch" ] || continue
    name=$(basename "$patch" .patch)
    if [[ " ${MACOS_PATCHES_NOT_USED[*]} " == *" $name "* ]]; then
      continue
    fi
    platform_patches+=("$ungoogled_macos/patches/$patch")
  done < "$ungoogled_macos/patches/series"
  platform_patches+=("$repo"/files/hudhud/macos/patches/*.patch)

  sh "$repo/files/hudhud/scripts/prepare-source.sh" "$src" "$ungoogled" "$repo/files/hudhud" \
    "${platform_patches[@]}"

  # The hoopoe icon (files/hudhud/logo/macos) instead of Chromium's: the
  # .icns for older macOS, the compiled asset catalogue for macOS 26 and
  # newer, which prefers it
  cp "$repo/files/hudhud/logo/macos/app.icns" "$repo/files/hudhud/logo/macos/Assets.car" \
    "$src/chrome/app/theme/chromium/mac/"
}

step_toolchain() {
  cd "$src"
  local ungoogled ini=$ungoogled_macos/downloads-arm64.ini
  ungoogled=$(ungoogled_dir)
  local llvm=third_party/llvm-build/Release+Asserts
  local rust=$src/third_party/rust-toolchain
  rm -rf "$llvm" "$rust" third_party/node/mac_arm64 bindgen-root
  mkdir -p "$llvm" third_party/node/mac_arm64/node-darwin-arm64

  # LLVM (clang 23) and Node.js, unpacked where Chromium looks for them
  python3 "$ungoogled/utils/downloads.py" unpack -c "$cache" -i "$ini" \
    --components llvm nodejs -- .
  # Chromium's macOS build runs install_name_tool from clang's directory, as
  # in its own LLVM package
  ln -sf llvm-install-name-tool "$llvm/bin/install_name_tool"

  # Rust, laid out as Chromium's own package (nix/browser/chromium-rust.sh): the
  # nightly installed with rustc's own crates (rustc-dev, for Crubit), its
  # version in VERSION, and the standard library's source with the crates
  # it uses, which Chromium compiles itself
  local unpack=$work/rust-unpack
  rm -rf "$unpack"
  mkdir -p "$unpack"
  tar -xJf "$cache/rust-nightly-$RUST_NIGHTLY.tar.xz" -C "$unpack"
  tar -xJf "$cache/rustc-dev-nightly-$RUST_NIGHTLY.tar.xz" -C "$unpack"
  "$unpack"/rust-nightly-aarch64-apple-darwin/install.sh --prefix="$rust" --disable-ldconfig \
    --components=rustc,cargo,rustfmt-preview,rust-std-aarch64-apple-darwin > /dev/null
  "$unpack"/rustc-dev-nightly-aarch64-apple-darwin/install.sh --prefix="$rust" --disable-ldconfig > /dev/null
  "$rust/bin/rustc" --version > "$rust/VERSION"
  mkdir -p "$rust/lib/rustlib/src/rust"
  tar -xJf "$cache/rustc-$(pinned chromium-rust version)-src.tar.xz" -C "$unpack" \
    rustc-nightly-src/library
  mv "$unpack/rustc-nightly-src/library" "$rust/lib/rustlib/src/rust/"
  rm -rf "$unpack"
  test -d "$rust/lib/rustlib/src/rust/library/vendor"

  # Crubit's cc_bindings_from_rs, built against that rustc (it runs inside
  # it) and installed into its toolchain, as nix/browser/crubit.sh does.  On
  # macOS rustc's crates link Rust's LLVM as a library of its own
  # (lib/libLLVM.dylib); librustc_driver is beside it.
  local crubit=$work/crubit
  rm -rf "$crubit"
  mkdir -p "$crubit"
  tar -xzf "$cache/crubit-$(pinned crubit version).tar.gz" -C "$crubit" --strip-components 1
  (
    cd "$crubit"
    RUSTC="$rust/bin/rustc" RUSTFLAGS="-L native=$rust/lib -Clink-args=-Wl,-rpath,@loader_path/../lib" \
      "$rust/bin/cargo" build --release --locked -p cc_bindings_from_rs --bin cc_bindings_from_rs
  )
  install -m 755 "$crubit/target/release/cc_bindings_from_rs" "$rust/bin/"
  mkdir -p "$rust/lib/third_party/crubit"
  cp -R "$crubit"/{BUILD.gn,LICENSE,crubit.gni,support} "$rust/lib/third_party/crubit/"
  "$rust/bin/cc_bindings_from_rs" --help > /dev/null

  # bindgen, with LLVM's libclang and the nightly's rustfmt beside it, where
  # rust_bindgen_root (configure) points
  cargo install --quiet --locked --root "$src/bindgen-root" bindgen-cli --version "$(pinned bindgen version)"
  ln -s "$src/$llvm/lib" bindgen-root/lib
  ln -s "$rust/bin/rustfmt" bindgen-root/bin/rustfmt

  # TypeScript (tsgo), where both Chromium and DevTools look for it
  rm -rf third_party/typescript/mac-arm64/src
  mkdir -p third_party/typescript/mac-arm64/src
  tar -xzf "$cache/tsgo.tgz" -C third_party/typescript/mac-arm64/src --strip-components 1
  # with the change Chromium's own package has: DOM setters that take
  # Trusted Types (microsoft/TypeScript#30024)
  patch --silent third_party/typescript/mac-arm64/src/lib/lib.dom.d.ts < third_party/node/patches/typescript.patch

  # Go, for Dawn's code generator: only its standard library is used
  mkdir -p third_party/dawn/tools/golang/mac-arm64/bin
  ln -sf "$(command -v go)" third_party/dawn/tools/golang/mac-arm64/bin/go

  # esbuild for DevTools: ungoogled-chromium prunes the prebuilt one, so
  # Homebrew's, with the npm module of the same version
  # (ungoogled-chromium-macos's fix-esbuild patch)
  local esbuild_version module=$work/esbuild-node/node_modules/esbuild
  esbuild_version=$(esbuild --version)
  npm install --prefix "$work/esbuild-node" --no-save --package-lock=false --no-bin-links \
    --ignore-scripts --omit=optional --no-audit --no-fund "esbuild@$esbuild_version" > /dev/null
  rm -rf third_party/devtools-frontend/src/node_modules/esbuild
  ln -s "$module" third_party/devtools-frontend/src/node_modules/esbuild

  # gn, from its source in the tarball
  mkdir -p "$out"
  python3 tools/gn/bootstrap/bootstrap.py -o "$out/gn" --skip-generate-buildfiles
}

step_configure() {
  cd "$src"
  if [ ! -f "$sdk/SDKSettings.json" ]; then
    echo "$sdk: not a macOS SDK (set HUDHUD_MACOS_SDK)" >&2
    exit 1
  fi
  # Chromium wants its SDK inside the output directory, to track it
  mkdir -p "$out/sdk"
  ln -sfn "$sdk" "$out/sdk/selected_macos_sdk"
  local ungoogled
  ungoogled=$(ungoogled_dir)
  # ungoogled-chromium's arguments, its macOS ones, then Hudhud's, which
  # win.  Not the macOS ones' Crubit directory: the toolchain step puts
  # Crubit inside Rust's, where Chromium looks by default.
  grep -v '^rust_crubit_root' "$ungoogled_macos/flags.macos.gn" > "$out/macos-args.gn"
  cat > "$out/hudhud-args.gn" <<ARGS
# Hudhud (docs/browser.md); as nix/browser/chromium.sh where they apply
target_cpu = "arm64"
# The source tarball has no PGO profiles
chrome_pgo_phase = 0
# No debug symbols, no ThinLTO: 16 GB of memory, and much less time
symbol_level = 0
blink_symbol_level = 0
v8_symbol_level = 0
use_thin_lto = false
enable_widevine = false
use_siso = false
clang_version = "23"
# V8's instance types from Torque, its older generator: metagen needs
# libclang's Python bindings, which come only as a prebuilt Linux package
v8_use_metagen = false
rust_bindgen_root = "$src/bindgen-root"
mac_sdk_path = "//out/Default/sdk/selected_macos_sdk"
ARGS
  sh "$repo/files/hudhud/scripts/merge-gn-args.sh" \
    "$ungoogled/flags.gn" "$out/macos-args.gn" "$out/hudhud-args.gn" > "$out/args.gn"
  cat "$out/args.gn"
  "$out/gn" gen "$out" --fail-on-unused-args
}

step_build() {
  # ANGLE's Metal shaders need Xcode's Metal toolchain, which an Xcode
  # update can leave behind (it is downloaded for one Xcode build)
  if ! xcrun metal --version > /dev/null 2>&1; then
    echo "Xcode's Metal toolchain is missing: xcodebuild -downloadComponent MetalToolchain" >&2
    exit 1
  fi
  # After a power cut ninja finds its deps log damaged and "recovers", but
  # leaves it so that every record it writes afterwards is unreadable too,
  # and each build starts over.  Rewriting the log from what loads keeps
  # it whole.
  ninja -C "$out" -t recompact
  # bindgen asks xcrun for the SDK, which follows SDKROOT
  SDKROOT=$sdk ninja -C "$out" -j "$jobs" chrome
}

# The Shields engine and the filter lists compiled into shields.dat, as
# nix/browser/hudhud-shields.sh builds them (the same lists, in the same order),
# put into the framework, where the browser loads them from
# (shields_engine.cc)
step_shields() {
  local lists=$work/lists
  rm -rf "$lists"
  mkdir -p "$lists/uAssets" "$lists/listear"
  tar -xzf "$cache/uAssets-$(pinned ublock-assets version).tar.gz" -C "$lists/uAssets" \
    --strip-components 1
  tar -xzf "$cache/listear-$(pinned liste-ar version).tar.gz" -C "$lists/listear" \
    --strip-components 1
  local engine=$work/shields-target/release
  CARGO_TARGET_DIR=$work/shields-target cargo build --release --locked \
    --manifest-path "$repo/files/hudhud/shields/Cargo.toml"
  local ua=$lists/uAssets
  "$engine/hudhud-shields-compile" "$work/shields.dat" \
    "$ua/thirdparties/easylist/easylist.txt" \
    "$ua/thirdparties/easylist/easyprivacy.txt" \
    "$ua/filters/filters.txt" \
    "$ua/filters/privacy.txt" \
    "$ua/filters/unbreak.txt" \
    "$ua/filters/quick-fixes.txt" \
    "$lists/listear/Liste_AR.txt"

  local framework="$out/Hudhud.app/Contents/Frameworks/Hudhud Framework.framework/Versions/Current"
  cp "$engine/libhudhud_shields.dylib" "$framework/Libraries/"
  cp "$work/shields.dat" "$framework/Resources/"
}

step_package() {
  local version app=$out/Hudhud.app
  version=$(chromium_version)

  sign_app "$app"

  local dmg=$work/hudhud-$version-macos-arm64.dmg
  "$src/chrome/installer/mac/pkg-dmg" --sourcefile --source "$app" --target "$dmg" \
    --volname Hudhud --symlink /Applications:/Applications --format UDBZ --verbosity 0
  # The disk image is signed too, so macOS can check it before opening it
  if [ "$identity" != - ]; then
    codesign --force --sign "$identity" --timestamp "$dmg"
  fi
  notarize "$dmg" "$app"
  echo "Built $dmg"
}

# Sign the app's code from the inside out: helpers, libraries, the framework,
# then the app.  With a certificate (HUDHUD_MACOS_SIGN_IDENTITY) everything
# carries its team's signature, so the hardened runtime and library
# validation can stay on, as in Chrome.  Without one the signature is ad hoc
# and only "kill" is used: library validation (and the hardened runtime,
# which implies it) loads only libraries of the app's own team, which an ad
# hoc signature has none of, and "restrict" without it stops the helpers
# finding their libraries through @executable_path.
sign_app() {
  local app=$1
  local framework="$app/Contents/Frameworks/Hudhud Framework.framework/Versions/Current"
  local entitlements=$ungoogled_macos/entitlements

  local helper
  for helper in "$framework/Helpers"/*; do
    # codesign's own temporary files, left by a signing that was stopped
    if [[ $helper == *.cstemp ]]; then
      continue
    fi
    local name
    name=$(basename "$helper" .app)
    case $name in
      *Renderer*) sign_code "$helper" --entitlements "$entitlements/helper-renderer-entitlements.plist" ;;
      *GPU*) sign_code "$helper" --entitlements "$entitlements/helper-gpu-entitlements.plist" ;;
      *) sign_code "$helper" ;;
    esac
  done
  local library
  for library in "$framework/Libraries"/*.dylib; do
    sign_code "$library"
  done
  sign_code "$framework/../.."
  # A profile embedded by an earlier run is not left behind without one
  rm -f "$app/Contents/embedded.provisionprofile"
  if [ -n "$profile" ]; then
    cp "$profile" "$app/Contents/embedded.provisionprofile"
    sign_code "$app" --entitlements "$repo/files/hudhud/macos/entitlements/app-entitlements.plist"
  else
    sign_code "$app" --entitlements "$entitlements/app-entitlements.plist"
  fi

  codesign --verify --deep --strict "$app"
  echo "Signed $app as: $(codesign -dvv "$app" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
}

# One piece of code, under its own bundle id (macOS keeps privacy
# permissions such as Local Network under it) or, for a bare executable or
# library, its file name
sign_code() {
  local code=$1
  shift
  local id
  if [ -f "$code/Contents/Info.plist" ]; then
    id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$code/Contents/Info.plist")
  elif [ -f "$code/Resources/Info.plist" ]; then
    id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$code/Resources/Info.plist")
  else
    id=$(basename "$code" .dylib)
  fi
  # The options sign_app explains: everything with a certificate, only
  # "kill" ad hoc; Apple's timestamp only means something with a certificate
  local options=restrict,library,runtime,kill timestamp=--timestamp
  if [ "$identity" = - ]; then
    options=kill
    timestamp=--timestamp=none
  fi
  if ! codesign --force --sign "$identity" --identifier "$id" \
      --options "$options" "$timestamp" "$@" "$code"; then
    echo "Signing $code failed.  Over SSH, unlock the keychain first:" >&2
    echo "  security unlock-keychain ~/Library/Keychains/login.keychain-db" >&2
    exit 1
  fi
}

# Notarized only with a Developer ID and the notarytool profile
# "hudhud-notary" (xcrun notarytool store-credentials hudhud-notary ...);
# anything else is for this Mac and Macs it is copied to with scp
notarize() {
  local dmg=$1 app=$2
  # Asked of the signed app, as the identity may be given by its hash.
  # (Not piped into grep -q: under pipefail, grep stopping early would fail
  # the check.)
  local signature is_developer_id=no
  signature=$(codesign -dvv "$app" 2>&1)
  if [[ $signature == *"Authority=Developer ID Application"* ]]; then
    is_developer_id=yes
  fi
  if [ $is_developer_id = no ] ||
     ! xcrun notarytool history --keychain-profile hudhud-notary > /dev/null 2>&1; then
    echo "Not notarized (needs a Developer ID and the hudhud-notary profile)"
    return
  fi
  xcrun notarytool submit "$dmg" --keychain-profile hudhud-notary --wait
  xcrun stapler staple "$dmg"
}

steps=(fetch source toolchain configure build shields package)
if [ $# -eq 0 ]; then
  use_python313
  for step in "${steps[@]}"; do
    "step_$step"
  done
elif [[ " ${steps[*]} " == *" $1 "* ]]; then
  use_python313
  "step_$1"
else
  echo "usage: $0 [${steps[*]}]" >&2
  exit 2
fi
