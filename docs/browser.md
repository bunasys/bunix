# A browser for bunix

Status (2026-11-06): being built.  Phase 0 (toolchain and libraries)
built on the Fly machine; Shields' engine built and tested.  Chromium 157
compiles with Hudhud's changes and runs (headless, on the Fly machine);
its packaged build and the desktop extension are next.

## The goal

Chromium, built here from source like every other package, with Brave's
privacy defaults:

- **Brave Search** is the default search engine.
- **Shields**, on by default with a per-site switch: ads and trackers
  blocked, third-party cookies blocked, HTTP upgraded to HTTPS.
  Fingerprinting protection comes later.
- **No Google services**: no Google sign-in or sync, no usage reports.
- Wayland only (niri), Arabic and right-to-left from day 0, usable by
  touch.

Out of scope: Brave's Rewards, wallet, VPN, AI assistant and news.

The browser is called **Hudhud** (هدهد, the hoopoe: the scout bird of
Sulayman's story, which goes ahead and comes back with what it found),
beside Buna Systems' Banan OS and Nawa Agent; named 2026-11-11.  Not
Chromium or Brave: their names and logos are trademarks.  It is part of
the desktop extension.

## Decisions

| Question | Choice |
| --- | --- |
| Name | Hudhud |
| Build host | a Fly.io machine, 16 CPUs and 48 GB, run only while building (tools/bst-fly.sh, tools/fly/README.md): about $1 an hour, $35 a month for its 200 GB cache volume |
| H.264 and AAC | yes: `proprietary_codecs = true`, `ffmpeg_branding = "Chrome"` |
| Ad blocking | adblock-rust built in from the start; no extension in between |
| Where it ships | the desktop extension |

## The elements

| Element | What | Rebuilt when |
| --- | --- | --- |
| base/chromium.bst | Chromium 157 with Hudhud's changes, in /usr/lib/hudhud: hours on the Fly machine | Chromium, a patch, the Shields code or the toolchain changes |
| base/hudhud-shields.bst | the Shields engine (libhudhud_shields.so) and the filter lists compiled into shields.dat | the lists or the engine change |
| base/hudhud.bst | the two above, the launcher, desktop entry, icons, recommended policies, first-run preferences | a default or an icon changes |

The split matters because BuildStream rebuilds an element from scratch
when any of its inputs changes: a new filter list must not cost a
Chromium build.  base/chromium.bst therefore reads only the engine's
header (files/hudhud/shields/include), not the engine.

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

- **The engine** (files/hudhud/shields): adblock-rust 0.13 behind a
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
- **Requests** (chrome/browser/hudhud_shields/shields_url_loader_factory):
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
  info now shows on every site (the shields-page-info-switch patch):
  Block (the default) is Shields
  up, Allow is down.
- **The Shields button** (chrome/browser/ui/views/hudhud_shields, the
  shields-button patches), right of the address bar: the hoopoe, with the number of ads
  and trackers blocked on the page as a badge, grey when Shields are down.
  Its panel shows the site, the count, the hosts blocked the most and the
  switch (the same "ads" setting, for the site's origin, as page info);
  flipping it reloads the page.  Counts are kept per page
  (shields_tab_helper.cc, also for a new tab's first page, whose frame
  host outlives the tab's empty first document), so a new page starts at
  zero; requests from
  shared and service workers are blocked but not counted.  English and
  Arabic strings are in the button's own table.
- Shields are a build target of their own (chrome/browser/hudhud_shields;
  the shields-build patches add it to Chromium's), so `gn check` holds.

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
- Counting requests from shared and service workers.
- An engine panic aborts the browser (panic = "abort": it must not unwind
  into C++); none is known in adblock-rust 0.13.

## Extensions

Installed from the Chrome Web Store, as in Brave (the user's choice,
2026-11-12); there is no other store.  ungoogled-chromium breaks the store
three ways, and Hudhud undoes each on top of it
(files/hudhud/ungoogled/patches/02-web-store.patch, on both platforms):

- Its domain substitution points the store's addresses and the store
  page's install API at hosts that do not exist.  The files that hold
  them, listed in files/hudhud/ungoogled/not-substituted.list, are left
  out of the substitution (files/hudhud/scripts/prepare-source.sh): the
  only Google addresses Hudhud may reach.
- Its patches empty the store installer and stop every update check.
  The installer comes back; update checks run for extensions only (the
  component updater stays off), against the store's own update server.
- The store page gets its own process again, as in Chromium.

What Google learns, and when: visiting the store is visiting a Google
site.  Installing sends one request (the extension's id, the OS, Hudhud's
version).  With store extensions installed, Hudhud checks for updates at
start and once a day, from the user's address, sending what Chromium's
update protocol carries: the extensions' ids and versions, active-day
counters (Google counts active installs from them) and install dates; no
account, no user id.  Hudhud sends none of the separate install, update or
uninstall event pings and does not say whether the computer is managed.
Not done (yet): an update proxy like Brave's, which would hide the user's
address from Google, or stripping the counters from the checks; Google's
remote "disable as malware" for extensions stays off, as
ungoogled-chromium has it.

## Password manager

The user chooses who keeps their passwords (2026-11-12), at the top of
chrome://password-manager's Settings: Hudhud's own password manager (the
default), 1Password, Bitwarden, Proton Pass, or none
(chrome/browser/hudhud_password_manager, the password-manager-choice
patches).

- **The choice** is the profile pref `hudhud.password_manager`:
  `builtin`, `off`, or an extension's id.  Anything but `builtin` stops
  Hudhud's own saving and filling: one gate in
  ChromePasswordManagerClient::IsFillingEnabled, which saving also asks.
  Passwords already saved stay on the device; choosing `builtin` again
  uses them, and turns "offer to save" back on.
- **With an extension chosen** the page shows a card instead of the
  password list: "Your passwords are in 1Password" and a button that opens
  the extension's own page, or installs it from the Chrome Web Store, or
  turns it back on in Extensions.  The card follows installs in other tabs.
- **The extensions** are a table in password_manager_choice_page.cc: id,
  name, the page to open (1Password's settings, Bitwarden's vault in a
  tab, Proton Pass's options).  Another password manager is one more row.
  All three handle passkeys in the page themselves.
- English and Arabic strings are in the same file.

Passkeys from macOS (iCloud Keychain, and password managers registered
with macOS) need Apple's browser passkey entitlement, which only a build
signed with a Developer ID that Apple granted it can have; the ad hoc
build has not.  Until then passkeys come from the extensions above.

## Defaults

- **Secure DNS** on, with the operating system's DNS server ("OS default",
  Chromium's automatic mode): ungoogled-chromium turns it off, Hudhud
  turns it back on (files/hudhud/ungoogled/patches/03-secure-dns.patch).
  Settings offer Cloudflare, Quad9, OpenDNS, CleanBrowsing or any other
  provider.
- **Search**: Chromium lists its search engines per country in a data
  file; files/hudhud/scripts/brave-search-first.py moves Brave to
  the front of every country's list (the first is the default) when
  Chromium is built.  Done on the data, not as a patch, so it keeps
  working as Google edits the lists.
- **Recommended policies** (the user can change them), in
  /usr/share/hudhud/policies (the policy-path patch: vendor defaults belong in
  the signed /usr): third-party cookies blocked, HTTPS-First (balanced),
  no usage reports.
- **First-run preferences** (/usr/lib/hudhud/initial_preferences):
  no sign-in, WebRTC shows only the public address, no first-run screens.
  Enforced policies would show "Managed by your organization", so none
  are used.
- No "Google API keys are missing" bar: ungoogled-chromium already has
  none.
- The profile lives in ~/.config/hudhud (the profile-directory patch);
  the launcher moves an earlier Buna Browser profile there once.

## Patches

Chromium's source is prepared the same way on Linux (base/chromium.bst)
and macOS (tools/build-macos.sh), by files/hudhud/scripts/prepare-source.sh:

1. ungoogled-chromium: its pruning of prebuilt binaries, then its patches;
2. the platform's own patches (macOS: ungoogled-chromium-macos's and
   files/hudhud/macos/patches; Linux: none);
3. files/hudhud/ungoogled/patches: Hudhud's changes to ungoogled-chromium's
   own (the Chrome Web Store, Secure DNS, building without private
   verification tokens);
4. Hudhud's code (files/hudhud/chromium) and files/hudhud/patches;
5. brave-search-first.py and hudhud-name.py (the browser's name in its
   strings, هدهد in Arabic, translations kept);
6. ungoogled-chromium's domain substitution, but for
   files/hudhud/ungoogled/not-substituted.list.

files/hudhud/patches are made by files/hudhud/make-patches.py from a tree
prepared up to step 3: every edit names the exact text it replaces, so a
new Chromium that moved it fails loudly there.  A patch's number is its
place in the generator's list; the docs name patches by name.

| Patch (by name) | What |
| --- | --- |
| shields-network | the request blocker in WillCreateURLLoaderFactory |
| shields-tab-helper | the element hider on every tab |
| shields-build, shields-tab-helper-build | Shields' own target in the browser's build |
| shields-page-info-switch | the per-site switch in page info on every site |
| shields-button, shields-button-build | the Shields button in the toolbar |
| policy-path | policies from /usr/share/hudhud/policies (Linux) |
| profile-directory | ~/.config/hudhud (Linux) |
| no-web-store-tile | no Web Store tile on the start page |
| password-manager-choice-* | the password manager choice: the gate, the pref, the page and their builds |
| no-related-google-services | no "Related Google services" section in Settings, Autofill |
| native-messaging-from-chrome | helpers registered for Google Chrome (1Password's) work too |
| safe-storage-name, safe-storage-name-linux | Hudhud's own keychain item and secret |

## Chromium updates

Hudhud follows Chromium's stable releases on ungoogled-chromium's patches
and lists, without waiting for ungoogled-chromium's own release.  Before
moving to a release, tools/chromium-update.py compares its source with the
current one and writes docs/chromium/<version>.md: Google addresses the
substitution does not cover, new prebuilt binaries, ungoogled-chromium's
patches that no longer apply, and the commits that name Google services.
Read it, note the conclusion at its top, then prepare-source.sh on the new
tree checks Hudhud's own patches.  tools/build-macos.sh refuses a Chromium
without its report.

## macOS

Hudhud for Apple Silicon Macs, built on a Mac by tools/build-macos.sh
(decided 2026-11-11), not by BuildStream: BuildStream builds in a Linux
sandbox, and a macOS app needs Apple's SDK from the Xcode installed there.
The sources stay pinned: Chromium's tarball, Rust's library source,
Crubit, bindgen's version and the filter lists come from the elements
Linux builds with; the rest is pinned in the script.

- **Base**: the same as Linux (Patches), plus ungoogled-chromium-macos,
  still at 156: what changed for 157 is in files/hudhud/macos/patches and
  files/hudhud/ungoogled/patches, and the script lists the macOS patches it
  does without and why.
- **Toolchain**: ungoogled-chromium-macos's prebuilt LLVM 23 and Node 24;
  Rust laid out as Chromium's own package, as on Linux (the 2026-09-10
  nightly with rustc-dev, the library source, Crubit built into it);
  bindgen from cargo; Chromium's pinned TypeScript (tsgo 7.0.2) from npm;
  Go and esbuild from Homebrew; the macOS 26 SDK (27's breaks LLVM 23's
  linker).
- **The app**: Hudhud.app (macos/patches/03-hudhud-branding.patch: name,
  bundle id com.bunasys.hudhud, team H575GQ7N4W), the hoopoe icon, its
  profile in ~/Library/Application Support/Hudhud.
- **Shields**: the same engine and lists, inside the framework
  (Libraries/libhudhud_shields.dylib, Resources/shields.dat), where
  shields_engine.cc looks on macOS.
- **Signing**: with the Developer ID when HUDHUD_MACOS_SIGN_IDENTITY is
  given (hardened runtime, library validation), notarized with the
  notarytool profile hudhud-notary; with its provisioning profile
  (HUDHUD_MACOS_PROVISIONING_PROFILE), the keychain group of Touch ID
  passkeys.  Ad hoc otherwise, for this Mac only.
- **Not yet on macOS**: the recommended policies and first-run
  preferences (macOS reads them from elsewhere); iCloud Keychain passkeys
  (Apple's entitlement, requested).

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
1. **Chromium on Wayland**, with Hudhud's changes (base/chromium.bst).
   Test in QEMU (virtio-gpu): it starts, loads a page over HTTPS, lays out
   an Arabic page right to left, plays sound; Shields block a known ad.
2. **Hudhud in the desktop extension** (base/hudhud.bst):
   launcher, desktop entry, icons, defaults; rebranding of the browser's
   own name and logos inside it.
3. **Shields, the rest**: scriptlets, re-hiding on page changes (the
   Shields button and panel are done).
4. **Fingerprinting protection**, a few of Brave's protections at a time.

## Open points

- Done (files/hudhud/scripts/hudhud-name.py, 2026-11-12): the browser
  calls itself Hudhud in its strings, هدهد in Arabic, with the
  translations kept.  Left: Hindi and Nepali write Chromium in their own
  script, chrome://version says "ungoogled-chromium", and the logos inside
  the browser are Chromium's.
- The icon (files/hudhud/logo, 2026-11-11): the letter ه as a ring
  whose stroke ends in a hook turning inward at the lower right, in
  Flame orange (#F2520B) on an indigo (#15182B) app icon.  Inside the
  browser the logos are still Chromium's (the same open point as the
  strings).
- Shields: whether to have an element picker ("block this on the page"),
  and whether users can add their own filter lists.
- Sound (phase 1 test): ALSA reaches PipeWire through the pipewire-alsa
  plugin, which needs the system's alsa-lib (1.2.15 or newer symbols).
  Google's prebuilt Chromium on the test machine was silent until its
  bundled libasound was moved aside (2026-11-05).  Check too that the audio
  process can open `/run/user/<uid>/pipewire-0` with its sandbox on.
