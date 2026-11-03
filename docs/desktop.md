# A graphical bunix: from boot to install

Status: plan (2026-11-03).  Phases 1 and 2 built and tested in QEMU.

## The goal

bunix boots to graphics with the Buna logo, runs on touch screens, and is
used graphically from the first screen of the live ISO to the end of the
install:

- the logo while the machine boots (live ISO and installed system);
- no wired network: a simple screen to join a Wi-Fi network;
- a graphical installer: disk, time zone, host name, root password, a
  normal user;
- Hyprland as the compositor, usable by touch;
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
| Compositor | Hyprland |
| `buna` and its screens | Rust + GTK4/libadwaita (gtk4-rs) |
| Languages | Arabic and English from day 0: right-to-left layouts, Arabic fonts and keyboard |
| Logo | `files/branding/buna-logo.svg` |

Arabic is a requirement from the first release, which decided the
toolkit: GTK4 mirrors whole layouts for right-to-left languages and has
input methods and screen-reader support; Slint, lighter and made for touch,
only shapes right-to-left text.  GTK4 costs about 30 more libraries (glib,
pango, harfbuzz, fribidi, gdk-pixbuf, graphene, libadwaita, ...).  Every
screen, `buna` included, is translated with gettext.

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
   - `plymouth.use-simpledrm`: until there are GPU drivers.
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

   **Then, before phase 3: the live ISO mounts /usr from the ISO.**  Today
   the whole root file system is the ISO's initramfs, in RAM, and the ISO
   carries /usr twice (the live system, and the image bunix-install
   writes): with firmware that is a 777 MB ISO that needs 2 GB of RAM.
   The live system will instead boot the same signed, dm-verity /usr image
   the installer copies, mounted from the boot medium, with only /etc and
   /var in RAM.

3. **Graphics stack.**  Mesa (iris, radeonsi, llvmpipe; LLVM), Wayland,
   libinput (mtdev, libevdev, libwacom), pixman, cairo, pango, fonts (Noto,
   Arabic: Naskh and Kufi), fribidi, harfbuzz, GTK4 and libadwaita,
   Hyprland and its libraries (hyprutils, hyprlang, hyprcursor,
   hyprgraphics, aquamarine).  systemd with logind and hwdb
   (libinput needs hwdb for touch screens).  No Xwayland at first.

4. **Users.**  polkit (with duktape), run0, logind sessions.  The live ISO
   runs its screens as an unprivileged user; time zone data (tzdata) and
   timedated, hostnamed.

5. **`buna`.**  A Rust program.  `update` and `ext` talk to sysupdated over
   D-Bus (systemd's `org.freedesktop.sysupdate1`, which reports progress);
   `doctor` collects what the boot checks look at today (failed units,
   Secure Boot and MOK state, /usr verity, free space, boot counting,
   network); `install` takes over `bunix-install`'s logic, which stays as
   the text-mode fallback until `buna install` passes the same tests.

6. **The graphical first run.**  The live ISO starts Hyprland as a kiosk
   with one app: welcome, network (Wi-Fi through iwd's D-Bus API when no
   cable is plugged in), then the installer (disk, time zone, host name,
   root password, user), progress, restart.  Touch: an on-screen keyboard
   and Hyprland's touch gestures.  Arabic and English, chosen on the first
   screen; the Arabic keyboard layout available everywhere.

7. **The installed desktop.**  A login screen, Hyprland session for the
   user, `buna update` as a graphical notification.

## Open points

- Arabic text on the boot splash (Plymouth needs pango for that); phase 1
  shows only the logo.
- /usr's size: firmware and the graphics stack grow /usr from 129 MB to
  maybe 600 MB; the 1 GiB slots still fit, but leave less room.
- An on-screen keyboard that handles Arabic.
