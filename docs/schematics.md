# Schematics: one image, many kinds of machine

Status: draft (2026-11-04).  Nothing built yet but the extensions it names
(gcc, rust, swift, devtools; desktop in progress).

## The problem

bunix should fit very different machines: an AMD laptop for a developer, an
Intel desktop for games, a locked-down kiosk, a classroom of shared PCs.
Each needs different firmware, drivers, software and defaults.

Building one image per kind of machine does not scale.  Four kinds of
hardware times five uses is twenty images to build, sign, test and publish
every release, on a build host with 7 GB of RAM.

The idea comes from Talos Linux, where a *schematic* (a small file listing
extensions and kernel arguments) describes a customised image, and the hash
of that file names it.  Talos must build an image per schematic, because it
merges extensions only at boot.  bunix merges system extensions at run time,
so it does not have to.

## The idea

There is **one** signed base: the `/usr` image and the UKI.  Everything
optional is already, or becomes, a sysupdate *feature* (a system extension,
or a configuration extension for `/etc`).  A schematic is only a choice of
features and kernel arguments, applied on the machine:

```
            one base image (/usr + UKI)       built and signed once per release
                       +
   features: gcc, rust, firmware-amd, ...     built and signed once per release
                       +
   schematic: which features, which           a small text file, chosen at
   kernel arguments                           install time, changeable later
```

A machine picks **hardware** schematics (what it is) and **one use**
schematic (what it is for), for example `amd laptop` + `developer`.

## What a schematic can set

Only two things, both delivered by mechanisms bunix already has or systemd
provides:

| Key | Delivered by | Applied by |
| --- | --- | --- |
| `Features=` | sysupdate features: sysexts (`/usr`) and confexts (`/etc`), signed verity images | a drop-in `/etc/sysupdate.d/<feature>.feature.d/schematic.conf` with `Enabled=true` |
| `KernelAddons=` | UKI add-ons (`<name>.addon.efi`): extra kernel command line, signed with the Secure Boot key | copied to `$BOOT/loader/addons/`, where systemd-stub loads them for every UKI |

Services an extension needs are enabled by presets inside the extension
itself, not by the schematic, so an extension works the same whichever
schematic pulled it in.

Global add-ons (`loader/addons/`), not per-UKI ones
(`bunix_<v>.efi.extra.d/`), because the UKI's file name changes with every
release and per-UKI add-ons would have to be copied on each update.

## The file format

systemd's INI style, like the `.feature` and `.transfer` files next to it:
nothing new to learn, and readable from a shell script.

```ini
# /usr/lib/bunix/schematics/developer.schematic
[Schematic]
Kind=use
Description=Developer machine: C, C++, Rust and Swift
Features=gcc rust swift devtools
```

```ini
# /usr/lib/bunix/schematics/amd.schematic
[Schematic]
Kind=hardware
Description=AMD processor and Radeon graphics
Features=firmware-amd mesa-radeon
KernelAddons=amd-pstate
```

```ini
# /usr/lib/bunix/schematics/laptop.schematic
[Schematic]
Kind=hardware
Description=Laptop: battery, power profiles, lid, sensors
Features=laptop
```

A machine's choice is stored in one file:

```ini
# /etc/bunix/machine.conf
[Machine]
Hardware=amd laptop
Use=developer
```

`Kind=hardware` schematics combine (an Intel processor with an NVIDIA card
is `intel nvidia`); exactly one `Kind=use` is chosen.

### The schematic ID

The ID is the SHA-256 of the *resolved* result: the sorted, de-duplicated
list of features and add-ons, one per line.  Two machines with the same ID
run the same bytes for a given release, whatever names were used to get
there.  `buna doctor` prints the names, the ID and the release, so a bug
report starts with all three.

## The hardware schematics

| Schematic | Features | Notes |
| --- | --- | --- |
| `generic` | none | Works everywhere through the firmware framebuffer; the default and the fallback. |
| `intel` | `firmware-intel`, `mesa-intel`, VA-API | |
| `amd` | `firmware-amd`, `mesa-radeon`, VA-API | |
| `nvidia` | `firmware-nvidia`, `nvidia` | Hardest: the kernel module must be built in the bunix pipeline against each kernel, because modules are signed with a throwaway build key. |
| `laptop` | `laptop` | power-profiles-daemon, battery charge limits, iio-sensor-proxy, fprintd, lid handling. |

**Firmware** moves out of the base: `system/firmware.bst` is split into
`firmware-<vendor>` extensions, which shrinks the base image.  The catch is
firmware needed before the extensions merge, such as GPU firmware for the
boot splash: that stays in the initrd, or travels next to the UKI as a sysext
(`bunix_<v>.efi.extra.d/*.sysext.raw`) that systemd-stub passes to the
initrd -- per UKI, so it must be installed again with each update.

**Arm is not a schematic.** It is another architecture: its own toolchain
bootstrap, `/usr` image and UKI, libraries in `/usr/lib/aarch64-linux-gnu`.
Board-specific pieces (device trees, boot firmware) would be per-board
hardware schematics on that architecture, like Talos's overlays.

`buna install` proposes the hardware schematics from what it finds:

- processor: `vendor_id` in `/proc/cpuinfo`;
- graphics: PCI devices of class `0x03` and their vendor (`0x8086` Intel,
  `0x1002` AMD, `0x10de` NVIDIA);
- laptop: a battery in `/sys/class/power_supply/`, or a portable chassis type
  in `/sys/class/dmi/id/chassis_type`.

The user can change the proposal before installing.

## The use schematics

| Schematic | Features | Notes |
| --- | --- | --- |
| `desktop` | `desktop` | The default: the graphical system (see below). |
| `console` | none | The base alone: servers, build machines, anything run over SSH or a serial line. |
| `developer` | `desktop`, `gcc`, `rust`, `swift`, `devtools` | All but `desktop` exist today; on a console, the same without `desktop`. |
| `gaming` | `mesa-*`, `vulkan`, `multiarch-i386`, `steam` | 32-bit libraries in `/usr/lib/i386-linux-gnu`: the multiarch layout pays off here.  Needs the `nvidia` work for most gaming PCs. |
| `school` | `school` (a confext) | Many users, settings managed by the school, factory reset between classes (`systemd-repart`'s `FactoryReset=`), Arabic from the first screen. |
| `kiosk` | see below | The one exception. |

### Desktop or console

The graphical system is not in the base image: it is the `desktop` feature,
a system extension with Mesa and libLLVM, Wayland, libinput, seatd, the
fonts' libraries, GTK4 and libadwaita, niri with DMS, and Ghostty.  The
base keeps what a console needs too: the kernel's GPU drivers and their
firmware (early KMS: native resolution, the boot splash), udev's hwdb, the
admin tools, the text installer.

```
                       live system     console install   desktop install
base /usr + UKI        from the stick  yes               yes
desktop extension      from the stick  no                yes
boots to               the installer   multi-user        graphical
```

- The live image carries `desktop_<release>.raw` next to the `/usr` image, and the
  live system merges it from the stick, checked by its dm-verity signature
  like every extension, before the graphical installer starts.  When
  graphics fail, the text installer is the fallback.
- The installer asks *Desktop or console?*: the use schematic.  For
  `desktop` it copies the extension from the stick into
  `/var/lib/extensions/desktop.raw.v/` (no network needed), enables the
  feature, so that updates fetch it with each new `/usr`, and links
  `default.target` to `graphical.target`.  For `console`, neither.
- `buna schematic set --use console` (or `desktop`) changes it later: no
  reinstall, because extensions merge at run time.
- The extension enables its own services (seatd, the session) through unit
  links inside it, so they exist only when it is merged.

### Kiosk is sealed

A kiosk must not change at run time, so it does not use run-time extensions
at all.  It is the one schematic that is its own image:

- one `/usr` with the kiosk's software -- and the desktop stack -- built
  in, no sysext merging
  (`ImagePolicy=` refuses every extension);
- `/etc` from a confext, read-only;
- one application started at boot on its own seat;
- updated by sysupdate like any other bunix, but only `/usr` and the UKI.

Entering or leaving kiosk mode is a reinstall.  Every other schematic can be
changed on a running system:

```
buna schematic show                      names, resolved features, ID
buna schematic set --use gaming          enable the new features, disable
                                         the old ones, update, refresh
buna schematic set --hardware amd laptop
```

## Testing

`updates.md` promises that what a machine runs is what CI built and tested.
Testing every combination is too expensive, so CI tests:

- every hardware schematic with the `desktop` use, and
- every use schematic with `generic` hardware,

each booted in QEMU by `tools/boot-test.py`.  Hardware schematics need real
hardware for their drivers; QEMU only proves they install, merge and boot.

Two checks run at build time, as BuildStream test elements:

- **No overlapping files.**  When two merged extensions ship the same path,
  overlay order silently decides which one wins.  The test fails if any two
  features that can appear in the same machine ship the same file.
- **Every name resolves.**  Every feature and add-on a schematic names exists
  in the release.

## Steps

1. The schematic and machine files, and `buna schematic show|set` for the
   existing features (`gcc`, `rust`, `swift`, `devtools`, `desktop`): the
   `desktop`, `console` and `developer` schematics.  The `desktop`
   extension is built in phase 3 of docs/desktop.md; the live image carrying it and
   the installer's question come with phase 6 there.
2. UKI add-ons: build, sign and install them; `KernelAddons=`.
3. Split `system/firmware.bst` into `firmware-<vendor>` extensions; the
   `intel` and `amd` schematics; hardware detection in `buna install`.
4. confexts, and the `school` schematic.
5. The `laptop` schematic.
6. The sealed kiosk image.
7. `gaming` and `nvidia`, the largest pieces of work.

## Open points

- **Dependencies between features.**  `rust` and `swift` need `gcc`; today
  only a comment in `rust.feature` says so.  Either the schematic lists every
  feature (simple, explicit), or extensions declare what they need and `buna`
  resolves it (needed anyway for `buna ext enable rust`).
- **Where schematics live.**  In `/usr/lib/bunix/schematics/`, so each
  release ships the ones it tested.  A school's own schematic would go in
  `/etc/bunix/schematics/`, but nothing tests it.
- **Users' own add-ons.**  An add-on must be signed with the Secure Boot key,
  so users cannot add kernel arguments without enrolling their own key.
  That is the point, but there should be a documented way to do it.
- **Kiosk updates.**  Whether a kiosk image is built for every release or
  only on demand.

## References

- Talos Linux, Image Factory and schematics:
  <https://www.talos.dev/latest/learn-more/image-factory/>
- systemd-sysupdate features: `sysupdate.features(5)`
- UKI add-ons: `systemd-stub(7)`, `ukify(1)`
- systemd-sysext and confext: `systemd-sysext(8)`
- `docs/updates.md`: how features are signed, published and fetched
