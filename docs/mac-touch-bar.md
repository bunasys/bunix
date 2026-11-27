# A MacBook Pro's Touch Bar

The 13-inch MacBook Pro with an M1 (J293, mbp20) or M2 (J493) has a
Touch Bar where other laptops have Escape and the function keys: the only
Escape it has.  Until bunix drives it, the bar is dark, and there is no
Escape key.  Begun 2026-11-27, on the `touch-bar` branch; on mbp20 with
test version 0.5.3.3 the same day, the bar draws its keys and takes
touches.

## What the bar is

- **A display of its own**, with its own display controller (ADP, not the
  DCP of the screen) and panel (Summit), which is also its backlight.
- **A touch screen** on SPI (Z2), which loads Apple's firmware for it at
  boot: `apple/dfrmtfw-<model>.bin`, the model named in the device tree.
- Neither draws anything by itself.  **tiny-dfr** (Asahi's) draws the
  keys -- Escape and F1 to F12, or with Fn brightness, volume and media --
  and sends what is touched as a keyboard of its own, through uinput.  It
  dims the bar after 30 seconds without a touch and turns it off after
  60.

## What bunix has

1. **The kernel** (`nix/boot/linux/aarch64.config`): ADP, Summit and Z2
   built in, and uinput.  On another Mac nothing of it starts: the device
   trees of Macs without a bar leave these parts off.
2. **The firmware.**  Found as Wi-Fi's is (docs/nix-usr-system.md, "On a
   Mac"), but not among the Wi-Fi files: Asahi's firmware tool makes it,
   in its multitouch step, from `fud_firmware/` in the archive of
   firmware the Mac's installer collects (`all_firmware.tar.gz`).  On an
   installed Mac, `vendor-firmware` has the touch screen tried again once
   `/var/lib/vendorfw` can be read, as it has Wi-Fi.

   mbp20's archive had the Wi-Fi files only, and the bar drew its keys
   but took no touch ("Direct firmware load for apple/dfrmtfw-j293.bin
   failed").  The file was made by hand: `Firmware/J293_Multitouch.im4p`
   alone, read out of Apple's restore image of the macOS the Mac runs
   (27.2.1, `UniversalMac_27.2.1_26B131_Restore.ipsw`) with ranged HTTP
   requests, converted by `asahi_firmware.multitouch` from
   `aurora-silicon/aurora-installer`, and put in
   `/var/lib/vendorfw/apple/`.  Then, as root, `echo spi0.0 >
   /sys/bus/spi/drivers_probe` and `systemctl restart tiny-dfr`, or a
   reboot.  An installed Mac made this way keeps it.
3. **tiny-dfr** in arm64's desktop extension (`nix/desktop.nix`, "The
   Touch Bar"), with librsvg, which it draws its icons with.  Its udev
   rules put the bar's display and touch screen on a seat of their own
   (`seat-touchbar`): niri and libinput, on seat0, leave them alone, and
   the bar's touches do not land on the screen.  They also name the bar's
   display and backlight for its unit, and start it when the bar's touch
   screen shows up.  After an extension is merged, udev goes over input,
   display and backlight devices again for these rules
   (`systemd-sysext.service.d/bunix.conf`).
4. **DMS**, two patches (`files/dms/`): the bar's backlight is a second
   one beside the screen's, and DMS took the first by name as the
   screen's, so its brightness slider and keys moved the bar
   (`backlights-by-type.patch`); and its brightness OSD popped up each
   time tiny-dfr dimmed or woke the bar
   (`brightness-osd-for-the-shown-device.patch`).

`tools/desktop-test.sh` checks, in a virtual machine, that tiny-dfr is in
arm64's extension, that udev takes its rules and systemd knows its unit,
and that it does not run on a machine with no bar.

## Not yet known or done

- Tried on mbp20: its keys type, Fn switches its layer, the screen's
  brightness slider moves the screen, and nothing pops up when the bar
  dims.
- A way for bunix to make the firmware file itself, so that no one does
  the steps above by hand (below).
- If `systemd-sysext` is restarted while the bar dims or wakes, the bar's
  devices lose their names for a moment, tiny-dfr stops with them, and
  nothing starts it again until the next boot.  A narrow window; at boot
  the merge comes before the bar can dim.

## Making the firmware: a plan

The file is Apple's, given with each Mac, and no one may pass it on: it
is not in this repository, a package or an image, and never will be.  What
bunix may ship is a way to make it on the person's own Mac, as Asahi's
and Aurora's installers do.  Planned, not written:

`bunix firmware` (src/bunix), run by the Mac's person, or by
`bunix-install` on a Mac with a bar:

1. What is wanted: the file the touch screen's node in the device tree
   names (`firmware-name`, `apple/dfrmtfw-j293.bin`), and the model.  On a
   Mac without a bar, nothing.
2. From Apple, and only Apple: its catalog of macOS restore images
   (`mesu.apple.com/assets/macos/com_apple_macOSIPSW/com_apple_macOSIPSW.xml`)
   names the newest.  Of that archive (25 GB) only its list of files and
   `Firmware/J<model>_Multitouch.im4p` (about 90 KB) are read, by ranges
   (`curl --range`; the command runs curl already).
3. Converted: the file is not compressed, an IM4P (DER) around an XML
   property list, which becomes the binary the driver reads, as
   `asahi_firmware/multitouch.py` (aurora-installer, MIT) does:
   `plist_to_bin_touchbar`, some 40 lines.
4. Put in `/var/lib/vendorfw/apple/`; the touch screen tried again
   (`spi0.0`), and tiny-dfr restarted.

Not at every boot by itself: a machine that asks Apple for files unasked
is a choice of its own.  Set aside: reading the file from the Mac's own
macOS (its Preboot volume is APFS, and a Mac mini's has no Multitouch
firmware, so it is not certain a laptop's has it either), and adding it
to the archive `tools/boot-mac.sh` takes, which covers a Mac booted from
another and not an installed one.
