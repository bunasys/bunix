# A browser for bunix

Status: plan (2026-11-05).  Nothing built yet.

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
logos are trademarks).

## Decisions

| Question | Choice |
| --- | --- |
| Name | Buna Browser |
| Build host | a Fly.io machine, 16 CPUs and 48 GB, run only while building (tools/bst-fly.sh, tools/fly/README.md): about $1 an hour, $35 a month for its 200 GB cache volume |
| H.264 and AAC | yes: `proprietary_codecs = true`, `ffmpeg_branding = "Chrome"` |
| Ad blocking | adblock-rust built in from the start (Shields option A); no extension in between |

## How Brave is made

brave-core is a set of patches and overriding files (`chromium_src/`) on
top of Chromium, MPL-2.0.  The parts that matter here:

- **Ad blocking** is [adblock-rust](https://github.com/brave/adblock-rust)
  (MPL-2.0): a Rust engine that reads EasyList and uBlock Origin filter
  lists.  The browser asks it about every network request, and it also
  hands out CSS selectors that hide ads on the page (cosmetic filtering).
  Brave downloads the lists from its own servers.
- **Search**: Brave Search is already one of Chromium's built-in engines
  (`components/search_engines/prepopulated_engines.json`, id 109); Brave
  only makes it the default.
- **Fingerprinting protection** ("farbling") adds random noise to canvas,
  audio and other APIs: many patches spread over Blink.
- The Shields panel and its per-site settings are Brave's own UI.

## Building Chromium here

One element, `base/chromium.bst` (kind `manual`):

- **Source**: Google's official tarball for distributions,
  `chromium-<version>-lite.tar.xz` from `chromium-browser-official`,
  pinned by checksum.  "Lite" leaves out the Debian sysroots and the
  bundled clang and Rust: distributions bring their own.  Our patches come
  as `patch` sources (the plugin is already in project.conf), from
  `files/chromium/patches/`.
- **gn** (Chromium's build file generator) is bootstrapped from the
  tarball; ninja is base's.
- **Toolchain**: our clang, lld and Rust, not Google's.  Chromium follows
  LLVM's and Rust's development branches, so a released toolchain needs a
  few flags and patches; Gentoo and Arch keep such patches and are the
  reference.  Chromium's own libc++ stays (every distribution keeps it).
- **Bundled libraries stay bundled** (ICU, HarfBuzz, FFmpeg, libvpx, ...),
  except what Chromium always takes from the system (fontconfig, NSS,
  Mesa's GBM, libdrm, libxkbcommon, Wayland, D-Bus, ALSA).  Unbundling
  means more patches with every release, for little gain.

A first `args.gn`:

```
is_official_build = true
is_debug = false
symbol_level = 0
treat_warnings_as_errors = false
use_sysroot = false
is_clang = true
clang_base_path = "/usr"
use_lld = true
rust_sysroot_absolute = "/usr"
ozone_platform = "wayland"
ozone_platform_wayland = true
ozone_platform_x11 = false
use_cups = false
use_kerberos = false
use_pulseaudio = false       # ALSA; pipewire-alsa makes PipeWire ALSA's default device
rtc_use_pipewire = true      # screen sharing through xdg-desktop-portal
enable_widevine = false
proprietary_codecs = true
ffmpeg_branding = "Chrome"   # FFmpeg with H.264 and AAC
```

### What bunix does not have yet

| Missing | Why Chromium needs it |
| --- | --- |
| Rust's std sources (`rust-src`) | Chromium compiles Rust's standard library itself; bootstrap/rust.bst installs only rustc and cargo |
| compiler-rt (clang's runtime libraries) | clang links them into Chromium; base/llvm.bst builds clang and lld only |
| Possibly a newer LLVM | Chromium tracks LLVM's main branch; LLVM 22 may be too old for Chromium 157 |
| Node.js (build only) | Chromium generates its built-in pages and DevTools with it |
| NSS and NSPR | certificates and the system's trusted roots (Chromium's TLS itself is its bundled BoringSSL) |
| at-spi2-core | accessibility (screen readers), required on Linux |
| GTK 3 headers, or no GTK | `use_gtk` builds against GTK 3 even when it runs with GTK 4; without GTK the file chooser goes through xdg-desktop-portal |

### What it costs

- **Build time**: by far the largest package.  Roughly a working day on 8
  cores, and every new version is a full rebuild (the source changes, so
  the cache key does).
- **Memory**: the heavy files take 1-2 GB each to compile, and linking
  the `chrome` binary takes several GB on its own.  pro13 (7 GB) can only
  run 2-3 jobs, which makes a build take days.  A build host with 32 GB
  and 16 or more cores is the realistic minimum.  Under Rosetta on the Mac
  it is not practical.
- **Cadence**: Chrome moved to a new major version every two weeks (from
  153), with security fixes in between.  The browser has to be rebuilt
  and shipped every week or two: the "continuously built" goal
  (docs/updates.md) at its hardest.
- **Size**: about 300 MB installed.

## Defaults without patches

Chromium reads policies, JSON files that set or lock its settings, from
`/etc/chromium/policies/{managed,recommended}/`.  *Recommended* policies
are defaults the user can still change.  These cover much of Shields at
no cost:

| Setting | Policy |
| --- | --- |
| Block third-party cookies | `BlockThirdPartyCookies` |
| Upgrade to HTTPS | `HttpsOnlyMode` / `HttpsUpgradesEnabled` |
| Hide the local IP from WebRTC | `WebRtcIPHandling` |
| No sign-in or sync | `BrowserSignin`, `SyncDisabled` |
| No usage reports | `MetricsReportingEnabled` |

Two small patches go with them:

- The policy directory moves to `/usr/share/buna-browser/policies`: vendor
  defaults belong in the signed /usr, and /etc stays the machine's own.
- Brave Search becomes the first engine for every country.  The search
  policies (`DefaultSearchProvider*`) can only be enforced, not
  recommended, and an enforced one shows "Managed by your organization".

## Shields: three ways to block ads

| | How | Blocks | Our work |
| --- | --- | --- | --- |
| A | adblock-rust inside the browser, as Brave does | requests, cosmetic filters, scriptlets: everything uBlock Origin's lists say | a hook in the network service, CSS injection in pages, the per-site switch and panel, list updates |
| B | Chromium's own `subresource_filter`, fed with EasyList (Bromite's and Cromite's way) | requests only, no cosmetic filtering | one patch and a list converter (`ruleset_converter`, in Chromium) |
| C | uBlock Origin Lite preinstalled | requests, some cosmetic filtering, within Manifest V3's limits | none: a file in `/usr/share/buna-browser/extensions/` |

Full uBlock Origin is not an option: it needs Manifest V2, which Chromium
removed (around 150-151).  Cromite's patches are GPL-3: reading them is
fine, copying them makes the browser GPL-3.

Chosen: **A, from the start.**  It is what Shields is, and C's Manifest V3
limits would only be a stopgap.  adblock-rust is Rust, which Chromium
already knows how to build (its crates are vendored and built by GN).
Filter lists ship in the image and are refreshed with every browser
release (every two weeks anyway), so nothing is fetched from a third
party's server by default.

## Phases

0. **Prerequisites.**  A build host big enough (see above).  `rust-src`
   and compiler-rt in the toolchain; LLVM bumped if Chromium needs it;
   Node.js, NSS, NSPR, at-spi2-core.
1. **Plain Chromium on Hyprland.**  base/chromium.bst, Wayland only.  Test
   in QEMU (virtio-gpu): it starts, loads a page over HTTPS, lays out an
   Arabic page right to left, plays sound.
2. **Buna Browser.**  Name and icon, Brave Search, the policies above, no
   Google services.  Not shipped yet: without Shields it is just Chromium.
3. **Shields.**  adblock-rust built into the browser: requests blocked in
   the network service, cosmetic filters and scriptlets injected into
   pages, EasyList, EasyPrivacy and uBlock Origin's lists in the image, the
   per-site switch and panel in the address bar.  Then shipped to desktop
   machines.
4. **Fingerprinting protection**, a few of Brave's protections at a time.

## Open points

- Shields: whether to have an element picker ("block this on the page"),
  and whether users can add their own filter lists.
- Its own system extension (`browser`) or part of `desktop`.  Its own
  fits better: it is large and updates far more often than the rest.
- GTK 3 headers for the GTK integration, or no GTK and the portal's file
  chooser (needs xdg-desktop-portal and a back end that has one).
- Sound (phase 1 test): ALSA reaches PipeWire through the pipewire-alsa
  plugin, which needs the system's alsa-lib (1.2.15 or newer symbols).
  Google's prebuilt Chromium on the test machine was silent until its
  bundled libasound was moved aside (2026-11-05).  Check too that the audio
  process can open `/run/user/<uid>/pipewire-0` with its sandbox on.
