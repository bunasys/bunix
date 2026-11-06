# A browser for bunix

Status (2026-11-06): being built.  Phase 0 (toolchain and libraries)
built on the Fly machine; Shields' engine built and tested.  Chromium 157
compiles with Buna's changes and runs (headless, on the Fly machine);
its packaged build and the desktop extension are next.

## The goal

Chromium, built here from source like every other package, with Brave's
privacy defaults:

- **Brave Search** is the default search engine.
- **Shields**, on by default with a per-site switch: ads and trackers
  blocked, third-party cookies blocked, HTTP upgraded to HTTPS.
  Fingerprinting protection comes later.
- **No Google services**: no Google sign-in or sync, no usage reports.
- Wayland only (Hyprland), Arabic and right-to-left from day 0, usable by
  touch.

Out of scope: Brave's Rewards, wallet, VPN, AI assistant and news.

The browser is called **Buna Browser** (Chromium's and Brave's names and
logos are trademarks).  It is part of the desktop extension.

## Decisions

| Question | Choice |
| --- | --- |
| Name | Buna Browser |
| Build host | a Fly.io machine, 16 CPUs and 48 GB, run only while building (tools/bst-fly.sh, tools/fly/README.md): about $1 an hour, $35 a month for its 200 GB cache volume |
| H.264 and AAC | yes: `proprietary_codecs = true`, `ffmpeg_branding = "Chrome"` |
| Ad blocking | adblock-rust built in from the start; no extension in between |
| Where it ships | the desktop extension |

## The elements

| Element | What | Rebuilt when |
| --- | --- | --- |
| base/chromium.bst | Chromium 157 with Buna's changes, in /usr/lib/buna-browser: hours on the Fly machine | Chromium, a patch, the Shields code or the toolchain changes |
| base/buna-shields.bst | the Shields engine (libbuna_shields.so) and the filter lists compiled into shields.dat | the lists or the engine change |
| base/buna-browser.bst | the two above, the launcher, desktop entry, icons, recommended policies, first-run preferences | a default or an icon changes |

The split matters because BuildStream rebuilds an element from scratch
when any of its inputs changes: a new filter list must not cost a
Chromium build.  base/chromium.bst therefore reads only the engine's
header (files/buna-browser/shields/include), not the engine.

Build tools, only for Chromium: base/llvm-23.bst, base/chromium-rust.bst,
base/crubit.bst, base/nodejs.bst, base/bindgen.bst, base/go.bst.
Libraries it takes from the system: NSS and NSPR (certificates; its TLS
is its own BoringSSL), at-spi2-core (accessibility), GLib, D-Bus, GTK 4,
Fontconfig, Mesa's GBM, libdrm, xkbcommon, Wayland, libffi, libpci (GPU
ids), libudev, ALSA, PipeWire (screen sharing).  Everything else (ICU, FFmpeg,
HarfBuzz, libvpx, ...) stays Chromium's own copy: unbundling means more
patches with every release, for little gain.

### What Chromium needs from the toolchain

Found in Chromium 157's source (2026-11-06):

- **clang**: Chromium follows LLVM's development branch (157 is built with
  LLVM 24's).  LLVM 22, the system's, is too old, and Mesa and Zig are
  pinned to it, so the browser gets its own build-only LLVM 23.1.5
  (base/llvm-23.bst, in /usr/lib/llvm-23).
- **compiler-rt**: Chromium links clang's `builtins` and `profile`
  runtime libraries from clang's own directory; base/llvm-23.bst builds
  those two.
- **Rust and Crubit**: Chromium 157 calls some of its Rust code (Blink's
  fonts, QR codes, CBOR, web bundles, ...) through C++ bindings made by
  Crubit's `cc_bindings_from_rs`, which only works with Chromium's own
  toolchain layout (`third_party/rust-toolchain`): a nightly rustc, the
  standard library's source (Chromium compiles it itself) and rustc's
  crates, which the generator is built against.  The system's Rust
  (`rust_sysroot_absolute`) is no longer enough, so base/chromium-rust.bst
  builds the 2026-09-10 nightly, the closest after Chromium's pinned
  commit (2026-09-09; no standard library file added or removed in
  between) against LLVM 23,
  and base/crubit.bst builds the generator at Chromium's pinned revision
  into it.  Chromium's other Crubit tool, `rs_bindings_from_cc`, is off by
  default and not built.
- **bindgen**: Chromium runs it for the C libraries its Rust code calls
  (base/logging, HarfBuzz, BoringSSL, ...): base/bindgen.bst, with LLVM
  23's libclang, and tidies the output with Chromium's Rust's rustfmt
  (Crubit's bindings too).
- **Node.js**: Chromium 157 is built with Node 24 and checks the exact
  version; base/nodejs.bst is the newest Node 24, and the check is given
  its version.  Node 24's `configure` refuses Python 3.15 by name, so
  `configure.py` is called directly.
- **gn**: bootstrapped from its source in the tarball, with LLVM 23's
  clang (its bootstrap looks for clang on PATH).
- **Go**: Dawn (WebGPU) generates part of Tint, its shader compiler, with
  a Go program during the build; it needs only Go's standard library.
  base/go.bst is Go 1.26 from source, compiled by a pinned binary Go 1.25
  (bootstrap/go-seed.bst), as Rust is from bootstrap/rust-seed.bst.
- **System libraries instead of Google's sysroot**: libffi
  (`use_system_libffi`), libpci (ANGLE's GPU ids), and OpenGL's headers
  from Mesa through a small gl.pc (Mesa installs none without GLX).
- **Left out**: VR headsets (`enable_openxr = false`; OpenXR's loader
  wants Vulkan's headers), besides CUPS, Kerberos, Qt, VA-API, Widevine
  and Google's API keys.
- **GTK**: `gtk_version = 4` builds against GTK 4's headers; GTK 3 is not
  needed.

## How Brave is made

brave-core is a set of patches and overriding files (`chromium_src/`) on
top of Chromium, MPL-2.0.  Its ad blocking is
[adblock-rust](https://github.com/brave/adblock-rust) (MPL-2.0): the
browser asks it about every network request, and it hands out CSS
selectors that hide ads on the page.  Brave Search is already one of
Chromium's built-in engines; Brave only makes it the default.
Fingerprinting protection ("farbling") is many patches spread over Blink.

## Shields

Full uBlock Origin was not an option (Chromium removed Manifest V2), nor
its Manifest V3 version (a stopgap with fixed rule limits); Chromium's own
`subresource_filter` blocks requests only.  Shields are Brave's engine
built in:

- **The engine** (files/buna-browser/shields): adblock-rust 0.13 behind a
  small C interface, in a shared library of its own.  Not linked into
  Chromium: Chromium links its own Rust standard library, and two copies
  in one binary clash.  The browser loads it at start
  (`base::LoadNativeLibrary`) from its own directory; if it is missing,
  the browser works without Shields.  adblock-rust's `single-thread`
  feature is off: the engine is loaded on one thread and used on another.
- **The lists**, pinned like any source and compiled into shields.dat
  when the engine is built (loading it takes milliseconds, parsing the
  lists seconds; uBlock Origin's `!#if` blocks are resolved for a
  Chromium browser, so Firefox-, Safari- and mobile-only rules are left
  out): EasyList and EasyPrivacy (from uBlock Origin's uAssets,
  which carries them), uBlock Origin's filters, privacy, unbreak and
  quick-fix lists, and Liste AR for Arabic sites.  Refreshed with each
  browser release; nothing is fetched from anyone's server.
- **Requests** (chrome/browser/buna_shields/shields_url_loader_factory):
  every web page's and worker's requests go through a factory placed in
  front of the network (`WillCreateURLLoaderFactory`, the hook Chromium's
  own extensions use), and so do their redirects.  Blocked requests fail
  with `ERR_BLOCKED_BY_CLIENT`, as in any ad blocker; a tab's own page is
  never blocked.  Whether a request is third-party is decided against the
  document that makes it (for a sandboxed frame, the site it came from).
  WebSockets do not go through this factory: `$websocket` rules do not
  apply yet.
- **Hiding** (shields_tab_helper): once a frame's document is parsed, and
  again once it has loaded, the site's own hiding rules apply, and the
  page's classes and ids are collected (in an isolated world the page
  cannot see) to find the generic rules that match them.
- **The per-site switch** is Chromium's "ads" content setting, which page
  info now shows on every site (patch 04): Block (the default) is Shields
  up, Allow is down.

Not yet (phase 3):
- uBlock Origin's resources: scriptlets (anti-anti-adblock scripts, which
  must run before the page's own) and the harmless stand-ins that
  `$redirect` rules serve instead of a blocked script.  Without them a
  `$redirect` rule blocks outright, which can stall a page that waits for
  the script (Google Tag Manager's callback, for one).
- Hiding with a user style sheet, from the renderer: today's `<style>`
  element is the page's own kind of style, so an inline `!important`
  beats it and the page can find and remove it.
- Re-hiding as pages change after load; matching off the UI thread;
  WebSockets.
- An engine panic aborts the browser (panic = "abort": it must not unwind
  into C++); none is known in adblock-rust 0.13.

## Defaults

- **Search**: Chromium lists its search engines per country in a data
  file; files/buna-browser/scripts/brave-search-first.py moves Brave to
  the front of every country's list (the first is the default) when
  Chromium is built.  Done on the data, not as a patch, so it keeps
  working as Google edits the lists.
- **Recommended policies** (the user can change them), in
  /usr/share/buna-browser/policies (patch 05: vendor defaults belong in
  the signed /usr): third-party cookies blocked, HTTPS-First (balanced),
  no usage reports.
- **First-run preferences** (/usr/lib/buna-browser/initial_preferences):
  no sign-in, WebRTC shows only the public address, no first-run screens.
  Enforced policies would show "Managed by your organization", so none
  are used.
- No "Google API keys are missing" bar (patch 07): there are no Google
  services to miss them.
- The profile lives in ~/.config/buna-browser (patch 06).

## Patches

files/buna-browser/patches, made from a pristine tree by
files/buna-browser/patches/make-patches.py: every edit names the exact text
it replaces, so a new Chromium version that moved it fails loudly there.

| Patch | What |
| --- | --- |
| 01-shields-network | the request blocker in WillCreateURLLoaderFactory |
| 02-shields-tab-helper | the element hider on every tab |
| 03-shields-build | Shields' sources in the browser's build |
| 04-shields-page-info-switch | the per-site switch in page info on every site |
| 05-policy-path | policies from /usr/share/buna-browser/policies |
| 06-profile-directory | ~/.config/buna-browser |
| 07-no-api-keys-infobar | no "Google API keys are missing" bar |

## What it costs

- **Build time**: by far the largest package, and every new version is a
  full rebuild.  On the Fly machine's 16 CPUs, an estimated 4-6 hours,
  about $5.
- **Cadence**: Chrome moves to a new major version every two weeks (from
  153), with security fixes in between: a rebuild every week or two.
- **Size**: about 300 MB installed.

## Phases

0. **Prerequisites.**  NSS, NSPR, at-spi2-core built; LLVM 23 with
   compiler-rt, Node 24, bindgen building.
1. **Chromium on Hyprland**, with Buna's changes (base/chromium.bst).
   Test in QEMU (virtio-gpu): it starts, loads a page over HTTPS, lays out
   an Arabic page right to left, plays sound; Shields block a known ad.
2. **Buna Browser in the desktop extension** (base/buna-browser.bst):
   launcher, desktop entry, icons, defaults; rebranding of the browser's
   own name and logos inside it.
3. **Shields, the rest**: scriptlets, re-hiding on page changes, the
   Shields panel.
4. **Fingerprinting protection**, a few of Brave's protections at a time.

## Open points

- The browser still calls itself Chromium inside (about page, menus):
  rebranding its strings keeps Chromium's Arabic translations only if
  their message ids are recomputed (as Brave's tooling does).
- The Arabic spelling of "Buna" for the desktop entry.
- The icon is the Buna logo; a browser icon of its own is not designed.
- Shields: whether to have an element picker ("block this on the page"),
  and whether users can add their own filter lists.
- Sound (phase 1 test): ALSA reaches PipeWire through the pipewire-alsa
  plugin, which needs the system's alsa-lib (1.2.15 or newer symbols).
  Google's prebuilt Chromium on the test machine was silent until its
  bundled libasound was moved aside (2026-11-05).  Check too that the audio
  process can open `/run/user/<uid>/pipewire-0` with its sandbox on.
