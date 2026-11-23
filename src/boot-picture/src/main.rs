//! boot-picture: draws the picture of a boot on a screen that a graphics
//! driver has just taken.
//!
//!   boot-picture /dev/fb0
//!
//! The picture is on the screen from before the kernel starts: systemd's
//! stub draws it, and nothing writes over it until the console has text
//! (docs/nix-usr-system.md, "What a boot shows").  But the stub drew on
//! what the firmware set up.  When a GPU's own driver takes the screen,
//! two things are lost until something draws through that driver:
//!
//!   - the kernel's way to say that it stopped: it draws its panic screen
//!     on what the driver last showed, and the driver has shown nothing;
//!   - on some machines the picture itself, where the driver starts with
//!     a screen of its own.
//!
//! So udev runs this for every screen as it appears (the rule it is
//! packaged with, nix/base/boot-picture.rules).  It draws the same
//! picture, in the middle as the stub did, and has the driver show it.
//!
//! It does nothing once the console has the screen: there is text on it
//! then, which is not this program's to draw over.

use std::fs::{File, OpenOptions};
use std::io::Write;
use std::os::fd::AsRawFd;
use std::os::raw::{c_int, c_ulong};
use std::process::ExitCode;

/// The picture systemd's stub drew (nix/images/uki.nix): the same file,
/// which nix/base/boot-picture.sh puts here.
const PICTURE_FILE: &str = "/usr/share/bunix/boot-picture.bmp";

fn main() -> ExitCode {
    let arguments: Vec<String> = std::env::args().skip(1).collect();
    let [screen_device] = arguments.as_slice() else {
        say("usage: boot-picture <a screen's device, as /dev/fb0>");
        return ExitCode::FAILURE;
    };
    match draw_on(screen_device) {
        Ok(what_was_done) => {
            say(&format!("{screen_device}: {what_was_done}"));
            ExitCode::SUCCESS
        }
        Err(why) => {
            say(&format!("{screen_device}: {why}"));
            ExitCode::FAILURE
        }
    }
}

/// One line, in the kernel's log: udev, which runs this, keeps what a
/// program prints to itself, and `dmesg` is where a boot is read.  At a
/// terminal, where the log is not this user's to write, the line is
/// printed.
fn say(line: &str) {
    // <6>: for the log, and not for the console (include/linux/kern_levels.h:
    // "info").  A line on the console would be the first text on the
    // screen, and take the picture away.
    let for_the_log = format!("<6>boot-picture: {line}\n");
    let logged = OpenOptions::new()
        .write(true)
        .open("/dev/kmsg")
        .and_then(|mut log| log.write_all(for_the_log.as_bytes()));
    if logged.is_err() {
        // nothing to do if that fails too
        let _ = writeln!(std::io::stderr(), "boot-picture: {line}");
    }
}

fn draw_on(screen_device: &str) -> Result<String, String> {
    if console_has_the_screen() {
        return Ok("left alone: the console has text on it".to_string());
    }
    let picture = Picture::read(PICTURE_FILE)?;
    let mut screen = Screen::open(screen_device)?;
    if !screen.is_drawn_on_here() {
        return Ok(format!(
            "left alone: its dots are of {} bits, laid out in a way that is not drawn on here",
            screen.layout.bits_per_pixel
        ));
    }
    screen.draw(&picture)?;
    screen.show()?;
    Ok(format!("the picture is drawn, on {} by {} dots", screen.width(), screen.height()))
}

/// The kernel lists its consoles in /sys/class/vtconsole, each with a
/// name and whether it is the one in use ("bind").  The one that draws
/// text on a screen calls itself "frame buffer device"; it is in use from
/// the first text written (CONFIG_FRAMEBUFFER_CONSOLE_DEFERRED_TAKEOVER),
/// and not listed before.
fn console_has_the_screen() -> bool {
    let Ok(consoles) = std::fs::read_dir("/sys/class/vtconsole") else {
        return false;
    };
    for console in consoles.flatten() {
        let name = std::fs::read_to_string(console.path().join("name")).unwrap_or_default();
        let in_use = std::fs::read_to_string(console.path().join("bind")).unwrap_or_default();
        let draws_on_a_screen = name.contains("frame buffer device");
        if draws_on_a_screen && in_use.trim() == "1" {
            return true;
        }
    }
    false
}

/// A picture as its dots, the top row first, each dot red, green, blue.
struct Picture {
    width: usize,
    height: usize,
    dots: Vec<[u8; 3]>,
}

/// More than any screen has: a number above it in a picture's file is
/// no size, but a file that is not what it says, or a height written as
/// a negative number (a picture kept top row first).
const LARGEST_SIDE: usize = 16384;

impl Picture {
    /// Reads the one kind of BMP that tools/render-branding.sh makes: 24
    /// bits a dot, not compressed.  Its rows are kept bottom first, each
    /// filled up to a multiple of four bytes, each dot as blue, green,
    /// red.
    fn read(file: &str) -> Result<Picture, String> {
        let bytes = std::fs::read(file).map_err(|error| format!("cannot read {file}: {error}"))?;

        // a BMP starts with two headers, of 14 bytes and of 40 or more
        let headers_are_whole = bytes.len() >= 14 + 40 && bytes.starts_with(b"BM");
        if !headers_are_whole {
            return Err(format!("{file} is not a BMP"));
        }
        // where the headers have each number, four bytes or two
        let number_at = |place: usize| u32::from_le_bytes([bytes[place], bytes[place + 1], bytes[place + 2], bytes[place + 3]]);
        let dots_start = number_at(10) as usize;
        let width = number_at(18) as usize;
        let height = number_at(22) as usize;
        let bits_a_dot = u16::from_le_bytes([bytes[28], bytes[29]]);
        let compression = number_at(30);

        let is_the_kind_read_here = bits_a_dot == 24 && compression == 0;
        if !is_the_kind_read_here {
            return Err(format!("{file} is not a BMP of 24 bits a dot, not compressed"));
        }
        let is_of_a_size = (1..=LARGEST_SIDE).contains(&width) && (1..=LARGEST_SIDE).contains(&height);
        if !is_of_a_size {
            return Err(format!("{file} is not a BMP kept bottom row first, of a size a screen has"));
        }
        let row_bytes = (width * 3).div_ceil(4) * 4;
        if bytes.len() < dots_start + row_bytes * height {
            return Err(format!("{file} ends before its last dot"));
        }

        let mut dots = Vec::with_capacity(width * height);
        for row_from_the_top in 0..height {
            let row_in_the_file = height - 1 - row_from_the_top;
            let row_start = dots_start + row_in_the_file * row_bytes;
            for column in 0..width {
                let dot = row_start + column * 3;
                let (blue, green, red) = (bytes[dot], bytes[dot + 1], bytes[dot + 2]);
                dots.push([red, green, blue]);
            }
        }
        Ok(Picture { width, height, dots })
    }

    fn dot(&self, column: usize, row: usize) -> [u8; 3] {
        self.dots[row * self.width + column]
    }
}

/// A screen as the kernel's fbdev interface has it: a file whose bytes
/// are the dots, row after row, and two descriptions of how they lie.
struct Screen {
    device: File,
    layout: VariableScreenInfo,
    bytes_a_row: usize,
}

impl Screen {
    fn open(screen_device: &str) -> Result<Screen, String> {
        let device = OpenOptions::new()
            .read(true)
            .write(true)
            .open(screen_device)
            .map_err(|error| format!("cannot open the screen: {error}"))?;

        let mut layout = VariableScreenInfo::default();
        let mut memory = FixedScreenInfo::default();
        // SAFETY: each call is given the struct the kernel fills for that
        // request, laid out as <linux/fb.h> has it, alive for the call.
        let asked = unsafe {
            ioctl(device.as_raw_fd(), FBIOGET_VSCREENINFO, &mut layout as *mut VariableScreenInfo) == 0
                && ioctl(device.as_raw_fd(), FBIOGET_FSCREENINFO, &mut memory as *mut FixedScreenInfo) == 0
        };
        if !asked {
            return Err(format!("the kernel would not describe it: {}", std::io::Error::last_os_error()));
        }
        Ok(Screen { device, layout, bytes_a_row: memory.line_length as usize })
    }

    /// Four bytes a dot, a byte a colour: what nearly every GPU's driver
    /// gives the console to draw on.  Another layout (a screen of ten
    /// bits a colour, as some firmware sets up) would need its own way of
    /// writing a dot, and is left as it is.
    fn is_drawn_on_here(&self) -> bool {
        let a_dot_is_four_bytes = self.layout.bits_per_pixel == 32;
        let each_colour_is_a_byte =
            self.layout.red.length == 8 && self.layout.green.length == 8 && self.layout.blue.length == 8;
        let a_row_holds_its_dots = self.bytes_a_row >= self.width() * 4;
        a_dot_is_four_bytes && each_colour_is_a_byte && a_row_holds_its_dots
    }

    fn width(&self) -> usize {
        self.layout.xres as usize
    }

    fn height(&self) -> usize {
        self.layout.yres as usize
    }

    /// Black, with the picture in the middle, not scaled: where systemd's
    /// stub drew it, so that it does not move when this draws it again
    /// (unless the driver gives the screen another size than the
    /// firmware did).
    fn draw(&mut self, picture: &Picture) -> Result<(), String> {
        // What of the picture is on the screen, and where.  A picture
        // larger than the screen loses the same at both sides.
        let shown_width = picture.width.min(self.width());
        let shown_height = picture.height.min(self.height());
        let left = (self.width() - shown_width) / 2;
        let top = (self.height() - shown_height) / 2;
        let cut_left = (picture.width - shown_width) / 2;
        let cut_top = (picture.height - shown_height) / 2;

        let black = self.as_the_screen_keeps([0, 0, 0]);
        let black_row = black.repeat(self.bytes_a_row / 4);

        for screen_row in 0..self.height() {
            let mut row = black_row.clone();
            let row_has_picture = screen_row >= top && screen_row < top + shown_height;
            if row_has_picture {
                let picture_row = cut_top + (screen_row - top);
                for column in 0..shown_width {
                    let dot = self.as_the_screen_keeps(picture.dot(cut_left + column, picture_row));
                    let place = (left + column) * 4;
                    row[place..place + 4].copy_from_slice(&dot);
                }
            }
            // no seek: the file starts at the screen's first row, and the
            // rows are written one after the other
            self.device
                .write_all(&row)
                .map_err(|error| format!("cannot write to the screen: {error}"))?;
        }
        Ok(())
    }

    /// A dot's four bytes: each colour where this screen's layout says.
    /// Where the fourth byte says how much of the dot shows (some Macs'
    /// screens), all of it does: left at nothing, the screen is black.
    fn as_the_screen_keeps(&self, [red, green, blue]: [u8; 3]) -> [u8; 4] {
        let shows_fully = if self.layout.transp.length == 8 { 0xff } else { 0 };
        let dot = (red as u32) << self.layout.red.offset
            | (green as u32) << self.layout.green.offset
            | (blue as u32) << self.layout.blue.offset
            | (shows_fully as u32) << self.layout.transp.offset;
        dot.to_le_bytes()
    }

    /// Has the driver show what was drawn.  What was written is in the
    /// kernel's memory only, until the screen is "set": which the kernel
    /// does when it is told the layout again, and to do so though nothing
    /// in it changed (FB_ACTIVATE_FORCE).  That is the drawing through
    /// the driver that the kernel's panic screen needs.
    ///
    /// The kernel says yes also where it showed nothing: with no display
    /// connected, or with a desktop that has the screen, which it then
    /// keeps.  There is no asking it which.
    fn show(&mut self) -> Result<(), String> {
        self.layout.activate = FB_ACTIVATE_NOW | FB_ACTIVATE_FORCE;
        // SAFETY: as in open(); the kernel reads the struct, and writes
        // back what it made of it.
        let shown = unsafe {
            ioctl(self.device.as_raw_fd(), FBIOPUT_VSCREENINFO, &mut self.layout as *mut VariableScreenInfo) == 0
        };
        if !shown {
            return Err(format!("the driver would not show it: {}", std::io::Error::last_os_error()));
        }
        Ok(())
    }
}

// ---- The kernel's fbdev interface, as <linux/fb.h> has it ------------------
//
// The standard library has no ioctl, and this program has no crate that
// would: the one function is declared here, and the structs it fills.

unsafe extern "C" {
    fn ioctl(file: c_int, request: c_ulong, ...) -> c_int;
}

const FBIOGET_VSCREENINFO: c_ulong = 0x4600;
const FBIOPUT_VSCREENINFO: c_ulong = 0x4601;
const FBIOGET_FSCREENINFO: c_ulong = 0x4602;
const FB_ACTIVATE_NOW: u32 = 0;
const FB_ACTIVATE_FORCE: u32 = 128;

/// struct fb_bitfield: where one colour is in a dot.
#[repr(C)]
#[derive(Default)]
struct ColourPlace {
    offset: u32,
    length: u32,
    msb_right: u32,
}

/// struct fb_var_screeninfo: the screen's size and how a dot is laid out.
#[repr(C)]
#[derive(Default)]
struct VariableScreenInfo {
    xres: u32,
    yres: u32,
    xres_virtual: u32,
    yres_virtual: u32,
    xoffset: u32,
    yoffset: u32,
    bits_per_pixel: u32,
    grayscale: u32,
    red: ColourPlace,
    green: ColourPlace,
    blue: ColourPlace,
    transp: ColourPlace,
    nonstd: u32,
    activate: u32,
    height: u32,
    width: u32,
    accel_flags: u32,
    pixclock: u32,
    left_margin: u32,
    right_margin: u32,
    upper_margin: u32,
    lower_margin: u32,
    hsync_len: u32,
    vsync_len: u32,
    sync: u32,
    vmode: u32,
    rotate: u32,
    colorspace: u32,
    reserved: [u32; 4],
}

/// struct fb_fix_screeninfo: the screen's memory; of it, how many bytes
/// a row takes (line_length), which may be more than its dots do.
#[repr(C)]
#[derive(Default)]
struct FixedScreenInfo {
    id: [u8; 16],
    smem_start: c_ulong,
    smem_len: u32,
    // "type" in the header: a word of Rust's
    kind: u32,
    type_aux: u32,
    visual: u32,
    xpanstep: u16,
    ypanstep: u16,
    ywrapstep: u16,
    line_length: u32,
    mmio_start: c_ulong,
    mmio_len: u32,
    accel: u32,
    capabilities: u16,
    reserved: [u16; 2],
}
