//! The shim's C interface (shim/shim.h), and a safe wrapper around it: all
//! of buna-kiosk's `unsafe` is here.  The shim owns everything aquamarine;
//! Rust only sees output numbers and events, drained from a queue after
//! each call.
use std::ffi::{CStr, c_char, c_int};

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

unsafe extern "C" {
    fn aq_create() -> *mut RawKiosk;
    fn aq_start(kiosk: *mut RawKiosk) -> bool;
    fn aq_poll_fds(kiosk: *mut RawKiosk, fds: *mut c_int, max: usize) -> usize;
    fn aq_dispatch(kiosk: *mut RawKiosk, fd: c_int);
    fn aq_next_event(kiosk: *mut RawKiosk, event: *mut RawEvent) -> bool;
    fn aq_output_enable(kiosk: *mut RawKiosk, output: u32, width: *mut i32, height: *mut i32) -> bool;
    fn aq_output_name(kiosk: *mut RawKiosk, output: u32) -> *const c_char;
    fn aq_output_fill(kiosk: *mut RawKiosk, output: u32, rgb: u32) -> bool;
    fn aq_output_schedule_frame(kiosk: *mut RawKiosk, output: u32);
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

/// aquamarine's DRM backend, with its seat session, through the shim.
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

    pub fn poll_fds(&self) -> Vec<c_int> {
        const MAX_FDS: usize = 64;
        let mut fds = [0 as c_int; MAX_FDS];
        let count = unsafe { aq_poll_fds(self.raw, fds.as_mut_ptr(), fds.len()) };
        if count == MAX_FDS {
            eprintln!("buna-kiosk: aquamarine has {MAX_FDS} or more fds to poll; only {MAX_FDS} are");
        }
        fds[..count].to_vec()
    }

    pub fn dispatch(&self, fd: c_int) {
        unsafe { aq_dispatch(self.raw, fd) }
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

    /// Asks for an OutputFrame event on the output.
    pub fn schedule_frame(&self, output: u32) {
        unsafe { aq_output_schedule_frame(self.raw, output) }
    }

    pub fn session_active(&self) -> bool {
        unsafe { aq_session_active(self.raw) }
    }

    pub fn switch_vt(&self, vt: u32) -> bool {
        unsafe { aq_switch_vt(self.raw, vt) }
    }
}
