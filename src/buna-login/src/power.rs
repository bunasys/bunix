//! Restart and power off, asked of logind over the system bus.  logind lets
//! the active session at the seat (this greeter's) do both without a
//! password, as long as nobody else is logged in; polkit decides otherwise.

use gtk::gio;
use gtk::glib;

pub enum PowerAction {
    Restart,
    PowerOff,
}

pub fn request(action: PowerAction) -> Result<(), glib::Error> {
    let method = match action {
        PowerAction::Restart => "Reboot",
        PowerAction::PowerOff => "PowerOff",
    };
    let bus = gio::bus_get_sync(gio::BusType::System, gio::Cancellable::NONE)?;
    let interactive = false;
    bus.call_sync(
        Some("org.freedesktop.login1"),
        "/org/freedesktop/login1",
        "org.freedesktop.login1.Manager",
        method,
        Some(&(interactive,).into()),
        None,
        gio::DBusCallFlags::NONE,
        -1,
        gio::Cancellable::NONE,
    )?;
    Ok(())
}
