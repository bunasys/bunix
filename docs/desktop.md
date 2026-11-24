# A graphical bunix: from boot to install

This is the plan and the state of 0.4.0, which BuildStream built.  Its
elements are kept, to port from, and no longer build.

## The port to Nix

The desktop extension (`nix/images/desktop.nix`, its packages in
`nix/desktop.nix`) comes back in four steps, for both architectures;
the next release waits for the last:

1. **First pixels** (done): Mesa, libinput and seatd, the text stack
   (FreeType, Fontconfig, HarfBuzz, FriBidi, cairo, pango), the fonts
   (Noto, and the Arabic fonts) and niri.  `tools/desktop-test.sh`
   merges the extension, checks which fonts the generic names are, in
   English and Arabic, starts niri, and has it take a picture of its
   screen.
2. **The shell** (done): Qt 6, Quickshell, DMS, greetd and dms-greeter,
   accountsservice, the session bus of a user, and PipeWire, whose
   library Quickshell links (DMS's interface will not load without it).
   `tools/desktop-test.sh` brings up the login screen, types a name and
   password on the machine's keyboard, and checks that the person's
   session comes up with DMS.
3. **Sound**: WirePlumber, which routes PipeWire's sound, and the arm64
   kernel's sound drivers, built in.
4. **The terminal and AppImages**: Alacritty, and FUSE (the kernel's,
   fusermount, libfuse 2 and 3) so that an AppImage runs; then the
   extension in releases.

What changed from 0.4.0:

- **No GTK 4**, libadwaita, gtk4-layer-shell, graphene or gdk-pixbuf, and
  Alacritty for a terminal where 0.4.0 had Ghostty, which is a GTK
  program.  Nothing of the rest needs GTK.
- **Noto Serif for serif**, where 0.4.0 had Noto Naskh Arabic first,
  which carries Latin letters too, and drew English serif text in them
  (`files/fontconfig/58-bunix-fonts.conf`).  Arabic serif text is still
  Naskh's.  And Kawkab Mono for Arabic in monospace, which was Noto Sans
  Arabic's, a proportional face.
- **Both architectures.**  On a Mac, Mesa's asahi driver draws with the
  GPU, which the kernel's driver (built in: `nix/boot/linux/aarch64.config`)
  runs.  The Mesa of arm64 is Aurora's (`aurora-silicon/mesa`), whose
  asahi driver has the GPUs of the M3 and later Macs as well as the M1's
  and M2's, where upstream's has only those two.  It is the commit
  Aurora's own distributions ship with the kernel bunix has, since the
  two must speak the same GPU interface; it moves when the kernel does.
  x86-64's Mesa is upstream's.
- **LLVM inside Mesa** (`nix/desktop/mesa.sh`): the extension carries the
  part of LLVM that Mesa uses, and not LLVM's whole library.  radeonsi
  compiles with ACO, Mesa's own compiler for AMD's GPUs, since LLVM is
  built without AMD's target (`files/mesa/`).
- **niri draws with llvmpipe when told to**, which upstream's never
  does: `BUNIX_NIRI_SOFTWARE_RENDERING=1` (`files/niri/`, two patches:
  the switch, and the render node such a renderer needs).  The test
  machines have no GPU that draws, and only the test sets it; a machine
  without a GPU Mesa drives gets no desktop, as upstream has it.
- **libinput without its Python tools** (`libinput measure`, `analyze`,
  `replay`): the system has no Python.
- **Qt without its build tools** (moc, qmlcachegen, qmake, the QML
  tools, and the files a build of Qt software reads): 35 MB unpacked,
  12 MB of the extension's file, which is 265 MB on arm64.
- **Not turned on from tty1**: the login screen takes tty1 as it starts,
  and with it the shell there, so `bunix ext enable desktop` typed on tty1
  stops before it changes anything, and points to tty2 or SSH.
- **C.UTF-8 in the base system** (`nix/base.nix`, `c-utf8-locale`): the
  locale systemd gives every service and session, and logins over SSH
  too, which 0.4.0 did not have compiled, so programs fell back to ASCII
  (Qt warned of it).

Status: plan (2026-11-04).  Phases 1 and 2 built, tested in QEMU and on
real hardware (an Intel Coffee Lake desktop).

## The goal

bunix boots to graphics with the Buna logo, runs on touch screens, and is
used graphically from the first screen of the live ISO to the end of the
install:

- the logo while the machine boots (live ISO and installed system);
- no wired network: a simple screen to join a Wi-Fi network;
- a graphical installer: disk, time zone, host name, root password, a
  normal user;
- niri as the compositor, with DMS (Dux Modular Shell) as the desktop
  shell and its login screen (since 0.3.0);
- a normal user next to root, who runs admin tasks through run0 + polkit;
- one command, `buna`, for the system's own jobs:

```
buna install                    install from the live ISO (refused on an installed system)
buna update                     update the system, with clear progress
buna doctor                     check the system's health
buna ext list                   the extensions (gcc, rust, swift, ...) and their state
buna ext enable|disable <name>
```

## What is there today

- Kernel: every driver built in, no loadable modules.  Graphics only through
  the firmware's framebuffer (simpledrm); no GPU drivers.  Wi-Fi drivers
  for Intel, Atheros, Realtek, MediaTek and Broadcom built in, but no
  firmware shipped (firmware/README.md).
- iwd for Wi-Fi, networkd and resolved for IP.
- systemd 261 without logind, hostnamed, timedated, localed, userdb, hwdb.
- Only root; its shell is fish.  No time zone data.
- `bunix-install`, a text installer (docs/install.md).

## Decisions

| Question | Choice |
| --- | --- |
| Boot splash | Plymouth, a bunix theme with the Buna logo |
| Kernel drivers | loadable modules (kmod), signed |
| Admin access | run0 + polkit |
| Compositor and shell | niri with DMS, a Quickshell (Qt/QML) shell; its login screen is dms-greeter, under greetd (`elements/desktop/`) |
| Graphics on the system | the `desktop` system extension, chosen at install: *Desktop or console?* (docs/schematics.md) |
| `buna` and its screens | Rust + GTK4/libadwaita (gtk4-rs) |
| Languages | Arabic and English from day 0: right-to-left layouts, Arabic fonts and keyboard |
| Logo | `files/branding/buna-logo.svg` |

Arabic is a requirement from the first release, which decided the
toolkit: GTK4 mirrors whole layouts for right-to-left languages and has
input methods and screen-reader support; Slint, lighter and made for touch,
only shapes right-to-left text.  GTK4 costs about 30 more libraries (glib,
pango, harfbuzz, fribidi, gdk-pixbuf, graphene, libadwaita, ...).  Every
screen, `buna` included, is translated with gettext.

### Units in an extension

The desktop extension brings systemd units of its own (the font cache,
accountsservice, greetd; later ALSA's volumes).  Two things make them
start:

- **systemd has to know them.**  It reads its units before
  `systemd-sysext.service` merges the extensions in early boot.  Every
  extension's `extension-release` file sets `EXTENSION_RELOAD_MANAGER=1`
  (`nix/images/extension-parts.sh`), so sysext reloads systemd right
  after the merge.
- **Something has to start them.**  The boot's jobs are planned before the
  merge, so a `.wants` link of `multi-user.target` would never be acted
  on.  Each unit is instead named by an `Upholds=` drop-in
  (`multi-user.target.d/<unit>.conf`): systemd starts an upheld unit
  whenever it is not running, including when it first appears.  An upheld
  unit must not fail at boot (prefix its command with `-`), or systemd
  keeps restarting it.

An extension's build refuses a service that nothing starts: no target
upholds it, and it has no socket of its own (`extension-parts.sh`; a
socket, as devtools' Nix daemon has, is started by `sockets.target`,
which the same drop-in asks again).  `tools/desktop-test.sh` checks that
the desktop's units run.

udev's rules and the system bus's policies are the same: each is read
before the merge.  After it, `systemd-sysext.service.d/bunix.conf` has
udev read its rules again and go over the input devices once more, for
libinput's rules; and has the bus read its policies again, without which
accountsservice cannot take its name on the bus.

## Phases

Each phase ends with a QEMU test, and with a release when it changes the
installed system.

1. **Boot splash.**  Plymouth (with libpng, libdrm, libevdev, xkbcommon,
   xkeyboard-config) and a bunix theme: the logo, centred, over a dark
   background, with a spinner.  In the ISO's initramfs and in the installed
   system's initrd; `quiet splash` on the command line; fbcon's deferred
   takeover so the firmware's picture stays until Plymouth draws.  Works on
   the firmware framebuffer, so it needs no GPU driver.

   Built (2026-11-03): the UKI carries the logo (`--splash`,
   files/branding/splash.bmp), so it appears as the boot image starts;
   Plymouth's bunix theme (files/plymouth/bunix) shows the same picture in
   the same place, with a spinner.  `tools/render-branding.sh` renders both
   from the SVG.  The boot menu is hidden and lists only bunix
   (`timeout 0`, `auto-entries no`): Windows starts from the firmware's
   menu.  Ctrl+Alt+F2 to F6 open root shells (logind's autovt@, the console
   shell for now).  What it took:
   - Plymouth finds screens through udev's "seat" tag, set by logind's
     rules: logind is now built and started.
   - With a serial console on the command line Plymouth shows only its
     text mode: `plymouth.ignore-serial-consoles`.
   - `plymouth.use-simpledrm`: until there are GPU drivers (dropped in
     0.1.9: early KMS loads them in the initrd).
   - fbcon's deferred takeover needs `CONFIG_FB` (without its firmware
     framebuffer drivers; simpledrm has the screen).
   - rootfs.bst wires units itself, so Plymouth's were added there.
   - Plymouth needs gettext's msgfmt (now in base) for its themes' titles.

2. **Modules and firmware.**  CONFIG_MODULES with kmod; modules signed at
   build time with a throwaway key (the kernel enforces signatures under
   Secure Boot).  GPU (i915, xe, amdgpu, nouveau), touch (hid-multitouch,
   i2c-hid, Wacom, Goodix, Elan) and Wi-Fi drivers as modules.
   linux-firmware, cut down to GPUs, Wi-Fi and Bluetooth and compressed, on
   the ISO and in /usr.

   Built (2026-11-03, release 0.1.4): kmod 34.3; the kernel's boot
   drivers (disks, file systems, console, wired NICs that need no
   firmware) stay built in, so the initrd needs no modules; GPU (i915, xe,
   amdgpu, radeon, and QEMU's bochs and virtio-gpu), Wi-Fi, Bluetooth,
   touch (hid-multitouch, i2c-hid, Wacom, Goodix, Elan, Intel ISH) and the
   NICs that load firmware are modules: 113 of them, 15 MB.  Signed with a
   key each kernel build generates and discards, `MODULE_SIG_FORCE`: no
   other module loads, Secure Boot or not.  system/firmware.bst: 245 MB
   of linux-firmware 20261019's 2 GB, zstd-compressed.  NVIDIA is left
   out (nouveau needs NVIDIA's large GSP firmware; nova, the Rust
   successor, is not ready).  Every machine gets the same signed /usr, so
   the installed system has all the modules; only the ones for its own
   hardware load.  What it took:
   - Intel's I2C touch devices need pin control and GPIO, the DesignWare
     I2C core and the common clock framework built in.
   - The live UKI no longer fits in 1 GB of RAM (the ISO is 777 MB): the
     boot tests use 2 GB, and the next step mounts /usr from the ISO.
   - The `devel` extension became `gcc`.  A machine with `devel` enabled
     sees no newer release ("No update needed": sysupdate takes a release
     as complete only if it has every enabled feature's file), so
     `devel` is turned off before the update.

   **Then, before phase 3: the live ISO mounts /usr from the ISO.**
   Built (2026-11-04, release 0.1.7): the live UKI's initrd finds the
   medium by its label, attaches the signed dm-verity /usr image on it and
   boots with root on tmpfs; the ISO is 640 MB and the live system uses
   about 80 MB of RAM.  Release 0.1.7 also brought early KMS (i915, xe in
   the initrd), CPU microcode, TPM2 measurements, zram swap, nftables and
   OpenSSH, and kernel hardening (lockdown, Landlock, Yama); 0.1.8 the
   admin tools (iproute2, rsync, GNU tar, pciutils, usbutils, nvme-cli,
   smartctl, mokutil, cryptsetup, tzdata, hostnamed, timedated) and the
   `devtools` extension (git, gdb, strace, file, unzip).  lsusb shows no
   vendor names, and warns, until hwdb comes with phase 3.

3. **Graphics stack**, in three steps, each tested in QEMU (llvmpipe) and
   on the Intel test machine (iris).  No Xwayland at first, no Vulkan yet.
   All of it goes into the `desktop` system extension
   (sysext/desktop-content.bst), not the base: a console install leaves it
   out, a desktop install merges it, the live ISO merges it from the stick
   (docs/schematics.md, "Desktop or console").  The kernel's GPU drivers,
   their firmware and hwdb stay in the base, which consoles need too.

   - **3a. The drivers.**  Mesa 26.2 for Wayland: EGL, GBM, OpenGL ES;
     iris and crocus (Intel), radeonsi (AMD), virgl (VMs), llvmpipe (the
     CPU, when there is no supported GPU).  Mesa 26 compiles the Intel
     drivers' OpenCL kernels while it builds, so it needs LLVM with clang,
     SPIRV-Tools and the SPIR-V translator at build time; the system keeps
     only libLLVM.  LLVM 22, the version Zig 0.17 needs (3c).  Wayland
     1.26, wayland-protocols, libinput (mtdev; libwacom with 3c), seatd
     and libseat, pixman, FreeType, Fontconfig; systemd's hwdb (device
     quirks for libinput, names for lsusb).
   - **3b. The compositor.**  niri, with its own static libdisplay-info,
     and DMS on it: the first pixels, from a console with seatd.
   - **3c. GTK4 and the terminal.**  glib, pango, harfbuzz, fribidi,
     cairo, gdk-pixbuf, graphene, GTK4, libadwaita, gtk4-layer-shell;
     Noto next to the Arabic fonts.  The terminal is Ghostty (libghostty),
     built with Zig 0.17 from Ghostty's release tarball and its pinned
     dependencies -- Zig is a build tool like clang, not part of the
     system.  The test: Ghostty under the compositor, and an Arabic
     window laid out right to left.

4. **Users.**  polkit (with duktape), run0, logind sessions.  The live ISO
   runs its screens as an unprivileged user; time zone data (tzdata) and
   timedated, hostnamed.

5. **`buna`.**  A Rust program.  `update` and `ext` talk to sysupdated over
   D-Bus (systemd's `org.freedesktop.sysupdate1`, which reports progress);
   `doctor` collects what the boot checks look at today (failed units,
   Secure Boot and MOK state, /usr verity, free space, boot counting,
   network); `install` takes over `bunix-install`'s logic, which stays as
   the text-mode fallback until `buna install` passes the same tests.

6. **The graphical first run.**  The ISO carries the `desktop` extension
   and the live system merges it from the stick.  Planned: it starts
   niri with one app, full screen: welcome, network (Wi-Fi through iwd's
   D-Bus API when no cable is plugged in), then the installer (desktop or
   console, disk, encryption, time zone, host name, root password, user),
   progress, restart.  A desktop install copies the extension from the
   stick, so it needs no network.  Touch: an on-screen keyboard and
   gestures.  Arabic and English, chosen on the first screen; the Arabic
   keyboard layout available everywhere.

   **Encryption** (one more choice, on by default for desktops): the root
   partition -- /etc, /var and /home, everything that is the user's -- is
   LUKS2.  /usr is not encrypted: it is the same public image on every
   machine, and dm-verity under the signed UKI already guards it against
   changes (docs/updates.md).  The boot partition holds only signed UKIs;
   swap is zram, in memory.
   - systemd-repart formats the root encrypted at first boot
     (`Encrypt=` in `repart.d/10-root.conf`), as it creates it today.
   - Unlocked by the TPM, bound to Secure Boot (PCR 7) and to bunix's
     signed PCR policy, so an update needs no new enrolment; with a PIN by
     default (`systemd-cryptenroll --tpm2-with-pin`), so a stolen machine
     does not unlock itself.  Machines without a TPM 2.0 use a passphrase.
   - A recovery key, shown once in the installer (as text and a QR code),
     for a cleared TPM or a new main board.
   - The initrd asks for the PIN or passphrase on the boot splash
     (Plymouth), in Arabic or English.

7. **The installed desktop.**  A login screen, a niri session with DMS
   for the user (0.3.0), `buna update` as a graphical notification.

## Open points

- The screen blinks off for 1-3 s when the Intel driver takes over from the
  firmware's picture, on the Coffee Lake test machine's eDP panel (and
  likely other Gen9 panels).  The firmware drives the panel's clock with
  spread spectrum (DPLL0 `ctrl1` 0x13, a 0.25% slower link: M/N data
  6937900, link 289079 over 2^23 and 2^19), the driver without (0x3; M/N
  6920601, 288358), so its seamless takeover ("fastset") check fails and
  it does a full modeset.  `i915.panel_use_ssc` does not change Gen9 DP
  clocks, and no integer link clock reproduces the firmware's M/N exactly:
  a fix has to inherit spread spectrum and the firmware's M/N, which
  belongs upstream.  Found with a signed UKI add-on carrying
  `drm.debug=0x1e` (`ukify build --stub=.../addonx64.efi.stub`, installed
  in `$BOOT/EFI/Linux/<uki>.efi.extra.d/`).

- A Mac's GPU drawing the desktop has not been tried: the tests' machines
  are virtual, and draw with llvmpipe.  The MacBook Pro M1 is the first
  to try it on, then an M3 or later Mac, which is what Aurora's Mesa is
  for.
- Arabic text on the boot splash (Plymouth needs pango for that); phase 1
  shows only the logo.
- /usr's size: the graphics stack lives in the `desktop` extension, not in
  /usr, so the base stays near today's 417 MB in its 1 GiB slots.  The
  extension (perhaps 250 MB unpacked, 100 MB compressed) is one more file
  per update for desktop machines, and on the ISO.
- Headers for building against the desktop libraries (GTK apps) belong
  with `gcc` or in a `desktop-devel` extension: not decided.
- An on-screen keyboard that handles Arabic.
