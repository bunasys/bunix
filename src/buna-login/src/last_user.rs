//! The user name of the last successful login, kept in the greeter's home
//! (/var/lib/greetd, which greetd's unit makes) so the next screen can
//! offer it.  Only a name, never anything secret; losing it costs nothing,
//! so neither reading nor writing reports a failure.

use std::path::PathBuf;

use gtk::glib;

fn path() -> PathBuf {
    glib::home_dir().join("last-user")
}

pub fn read() -> Option<String> {
    let name = std::fs::read_to_string(path()).ok()?;
    let name = name.trim();
    if name.is_empty() {
        return None;
    }
    Some(name.to_string())
}

pub fn write(name: &str) {
    let _ = std::fs::write(path(), name);
}
