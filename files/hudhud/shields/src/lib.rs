//! Buna Browser's Shields engine: adblock-rust behind a small C interface
//! (include/buna_shields.h), which the browser loads as a shared library.
//!
//! The filter lists are compiled into one engine file when the browser is
//! built (src/bin/compile.rs); the browser only loads that file and asks
//! questions of it:
//! - should this request be blocked?
//! - which elements of this page should be hidden?
//!
//! Strings cross the interface as NUL-terminated UTF-8; lists and sets
//! as JSON.  Strings returned here are freed with
//! `buna_shields_free_string`.

use adblock::Engine;
use adblock::request::Request;
use std::collections::HashSet;
use std::ffi::{CStr, CString, c_char};

pub struct BunaShields {
    engine: Engine,
}

/// Loads an engine file made by buna-shields-compile.  Null if the data is
/// not one.
///
/// # Safety
/// `data` points to `len` readable bytes.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn buna_shields_load(data: *const u8, len: usize) -> *mut BunaShields {
    if data.is_null() {
        return std::ptr::null_mut();
    }
    let bytes = unsafe { std::slice::from_raw_parts(data, len) };
    let mut engine = Engine::default();
    if engine.deserialize(bytes).is_err() {
        return std::ptr::null_mut();
    }
    Box::into_raw(Box::new(BunaShields { engine }))
}

/// # Safety
/// `shields` comes from `buna_shields_load` (or is null) and is not used
/// afterwards.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn buna_shields_free(shields: *mut BunaShields) {
    if !shields.is_null() {
        drop(unsafe { Box::from_raw(shields) });
    }
}

/// Whether the filter lists block a request for `url`, made by a page at
/// `source_url`.  `request_type` is adblock-rust's name for what is loaded:
/// "script", "image", "stylesheet", "font", "media", "sub_frame", "xhr",
/// "object", "ping", "other".
///
/// # Safety
/// `shields` comes from `buna_shields_load`; the strings are valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn buna_shields_should_block(
    shields: *const BunaShields,
    url: *const c_char,
    source_url: *const c_char,
    request_type: *const c_char,
) -> bool {
    let (Some(shields), Some(url), Some(source_url), Some(request_type)) = (
        unsafe { shields.as_ref() },
        unsafe { to_str(url) },
        unsafe { to_str(source_url) },
        unsafe { to_str(request_type) },
    ) else {
        return false;
    };
    let Ok(request) = Request::new(url, source_url, request_type, "get") else {
        return false;
    };
    shields.engine.check_network_request(&request).should_block()
}

/// What to hide on the page at `url`, as JSON:
/// `{"hide_selectors": [...], "exceptions": [...], "generichide": bool}`.
/// `hide_selectors` apply as they are; `exceptions` go back into
/// `buna_shields_hidden_selectors`; with `generichide`, generic rules do
/// not apply to this page at all.
///
/// # Safety
/// `shields` comes from `buna_shields_load`; `url` is valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn buna_shields_page_resources(
    shields: *const BunaShields,
    url: *const c_char,
) -> *mut c_char {
    let (Some(shields), Some(url)) = (unsafe { shields.as_ref() }, unsafe { to_str(url) }) else {
        return std::ptr::null_mut();
    };
    let resources = shields.engine.url_cosmetic_resources(url);
    let json = serde_json::json!({
        "hide_selectors": resources.hide_selectors,
        "exceptions": resources.exceptions,
        "generichide": resources.generichide,
    });
    to_c_string(json.to_string())
}

/// The generic hiding rules that apply to elements with these classes and
/// ids, as a JSON list of CSS selectors.  All three arguments are JSON
/// lists of strings; `exceptions` is the page's, from
/// `buna_shields_page_resources`.
///
/// # Safety
/// `shields` comes from `buna_shields_load`; the strings are valid.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn buna_shields_hidden_selectors(
    shields: *const BunaShields,
    classes_json: *const c_char,
    ids_json: *const c_char,
    exceptions_json: *const c_char,
) -> *mut c_char {
    let Some(shields) = (unsafe { shields.as_ref() }) else {
        return std::ptr::null_mut();
    };
    let classes: Vec<String> = unsafe { parse_json_list(classes_json) };
    let ids: Vec<String> = unsafe { parse_json_list(ids_json) };
    let exceptions: HashSet<String> = unsafe { parse_json_list(exceptions_json) }.into_iter().collect();
    let selectors = shields.engine.hidden_class_id_selectors(&classes, &ids, &exceptions);
    to_c_string(serde_json::Value::from(selectors).to_string())
}

/// # Safety
/// `string` comes from this library (or is null) and is not used afterwards.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn buna_shields_free_string(string: *mut c_char) {
    if !string.is_null() {
        drop(unsafe { CString::from_raw(string) });
    }
}

unsafe fn to_str<'a>(string: *const c_char) -> Option<&'a str> {
    if string.is_null() {
        return None;
    }
    unsafe { CStr::from_ptr(string) }.to_str().ok()
}

/// A missing or malformed list is an empty one: the page then gets fewer
/// elements hidden, never an error.
unsafe fn parse_json_list(json: *const c_char) -> Vec<String> {
    unsafe { to_str(json) }
        .and_then(|json| serde_json::from_str(json).ok())
        .unwrap_or_default()
}

fn to_c_string(string: String) -> *mut c_char {
    // JSON never contains a NUL byte: serde_json escapes it
    CString::new(string).map_or(std::ptr::null_mut(), CString::into_raw)
}
