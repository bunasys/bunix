//! The shim's C interface (shim/shim.h), and a safe wrapper around it: all
//! of buna-kiosk's `unsafe` is here.  The shim owns everything aquamarine;
//! Rust only sees output numbers and events, drained from a queue after
//! each call.
use std::ffi::{CStr, c_char, c_int, c_ulong};
use std::time::Duration;

#[repr(C)]
struct RawKiosk {
    _private: [u8; 0],
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
struct RawEvent {
    kind: u32,
    output: u32,
    key: u32,
    pressed: bool,
}

// shim.h's event kinds, by the same numbers
const AQ_EVENT_NEW_OUTPUT: u32 = 1;
const AQ_EVENT_OUTPUT_GONE: u32 = 2;
const AQ_EVENT_OUTPUT_FRAME: u32 = 3;
const AQ_EVENT_OUTPUT_RECONFIGURE: u32 = 4;
const AQ_EVENT_KEY: u32 = 5;
const AQ_EVENT_SESSION_ACTIVE: u32 = 6;
const AQ_EVENT_SESSION_INACTIVE: u32 = 7;

#[repr(C)]
struct PollFd {
    fd: c_int,
    events: i16,
    revents: i16,
}
const POLLIN: i16 = 0x1;
const POLLERR: i16 = 0x8;
const POLLHUP: i16 = 0x10;
const POLLNVAL: i16 = 0x20;

unsafe extern "C" {
    fn poll(fds: *mut PollFd, count: c_ulong, timeout_ms: c_int) -> c_int;

    fn aq_create() -> *mut RawKiosk;
    fn aq_start(kiosk: *mut RawKiosk) -> bool;
    fn aq_poll_fds(kiosk: *mut RawKiosk, fds: *mut c_int, max: usize) -> usize;
    fn aq_dispatch(kiosk: *mut RawKiosk, fd: c_int);
    fn aq_next_event(kiosk: *mut RawKiosk, event: *mut RawEvent) -> bool;
    fn aq_output_enable(kiosk: *mut RawKiosk, output: u32, width: *mut i32, height: *mut i32) -> bool;
    fn aq_output_name(kiosk: *mut RawKiosk, output: u32) -> *const c_char;
    fn aq_output_fill(kiosk: *mut RawKiosk, output: u32, rgb: u32) -> bool;
    fn aq_session_active(kiosk: *mut RawKiosk) -> bool;
    fn aq_switch_vt(kiosk: *mut RawKiosk, vt: u32) -> bool;
}

/// What aquamarine reported, in the order it happened.
pub enum Event {
    NewOutput(u32),
    OutputGone(u32),
    /// The output can take the next frame (after a page flip, or when
    /// aquamarine asks for a redraw).
    #[allow(dead_code)] // phase 1 draws one colour; phase 2 draws each output per frame
    OutputFrame(u32),
    /// The output lost its mode and must be enabled again.
    OutputReconfigure(u32),
    /// An evdev key code, pressed or released.
    Key { code: u32, pressed: bool },
    SessionActive,
    SessionInactive,
}

/// aquamarine's DRM backend, with its seat session, through the shim.  It is
/// never destroyed (no Drop): destroying it would turn the screens off, and
/// the kiosk leaves its last picture lit when it exits (docs/kiosk.md).
pub struct Aquamarine {
    raw: *mut RawKiosk,
}

impl Aquamarine {
    /// None when there is no DRM device or no seat.
    pub fn create() -> Option<Aquamarine> {
        let raw = unsafe { aq_create() };
        if raw.is_null() { None } else { Some(Aquamarine { raw }) }
    }

    pub fn start(&self) -> bool {
        unsafe { aq_start(self.raw) }
    }

    /// Waits until aquamarine has something to do, or the timeout (None:
    /// none) passes, and lets it do it; its events are then in the queue.
    /// An error when one of its fds broke (seatd gone, say): it would wake
    /// this at once, forever.
    pub fn wait(&self, timeout: Option<Duration>) -> Result<(), String> {
        let mut fds: Vec<PollFd> =
            self.poll_fds().into_iter().map(|fd| PollFd { fd, events: POLLIN, revents: 0 }).collect();
        let timeout_ms = match timeout {
            None => -1,
            Some(timeout) => timeout.as_millis().min(c_int::MAX as u128) as c_int,
        };
        let ready = unsafe { poll(fds.as_mut_ptr(), fds.len() as c_ulong, timeout_ms) };
        if ready < 0 {
            let error = std::io::Error::last_os_error();
            let interrupted = error.kind() == std::io::ErrorKind::Interrupted;
            return if interrupted { Ok(()) } else { Err(format!("poll: {error}")) };
        }
        for fd in &fds {
            let is_broken = fd.revents & (POLLERR | POLLHUP | POLLNVAL) != 0;
            if is_broken {
                return Err(format!("fd {} broke (poll revents {:#x})", fd.fd, fd.revents));
            }
            if fd.revents & POLLIN != 0 {
                unsafe { aq_dispatch(self.raw, fd.fd) }
            }
        }
        Ok(())
    }

    fn poll_fds(&self) -> Vec<c_int> {
        const MAX_FDS: usize = 64;
        let mut fds = [0 as c_int; MAX_FDS];
        let count = unsafe { aq_poll_fds(self.raw, fds.as_mut_ptr(), fds.len()) };
        if count == MAX_FDS {
            eprintln!("buna-kiosk: aquamarine has {MAX_FDS} or more fds to poll; only {MAX_FDS} are");
        }
        fds[..count].to_vec()
    }

    pub fn next_event(&self) -> Option<Event> {
        let mut raw = RawEvent::default();
        if !unsafe { aq_next_event(self.raw, &mut raw) } {
            return None;
        }
        let event = match raw.kind {
            AQ_EVENT_NEW_OUTPUT => Event::NewOutput(raw.output),
            AQ_EVENT_OUTPUT_GONE => Event::OutputGone(raw.output),
            AQ_EVENT_OUTPUT_FRAME => Event::OutputFrame(raw.output),
            AQ_EVENT_OUTPUT_RECONFIGURE => Event::OutputReconfigure(raw.output),
            AQ_EVENT_KEY => Event::Key { code: raw.key, pressed: raw.pressed },
            AQ_EVENT_SESSION_ACTIVE => Event::SessionActive,
            AQ_EVENT_SESSION_INACTIVE => Event::SessionInactive,
            unknown => panic!("the shim sent an event of unknown kind {unknown}"),
        };
        Some(event)
    }

    /// Sets the output to be turned on at its preferred mode (the next
    /// fill applies it); its size in pixels.
    pub fn enable_output(&self, output: u32) -> Option<(i32, i32)> {
        let (mut width, mut height) = (0, 0);
        let enabled = unsafe { aq_output_enable(self.raw, output, &mut width, &mut height) };
        if enabled { Some((width, height)) } else { None }
    }

    pub fn output_name(&self, output: u32) -> String {
        let name = unsafe { CStr::from_ptr(aq_output_name(self.raw, output)) };
        name.to_string_lossy().into_owned()
    }

    /// Fills the output's next frame with one 0xRRGGBB colour and shows it.
    pub fn fill_output(&self, output: u32, rgb: u32) -> bool {
        unsafe { aq_output_fill(self.raw, output, rgb) }
    }

    pub fn session_active(&self) -> bool {
        unsafe { aq_session_active(self.raw) }
    }

    pub fn switch_vt(&self, vt: u32) -> bool {
        unsafe { aq_switch_vt(self.raw, vt) }
    }
}
