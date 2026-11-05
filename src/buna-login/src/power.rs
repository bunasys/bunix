//! Restart and power off, asked of logind over the system bus.  logind lets
//! the active session at the seat (this greeter's) do both without a
//! password, as long as nobody else is logged in; polkit decides otherwise.
//! Asynchronous, so a slow answer does not freeze the screen.

use gtk::gio;
use gtk::glib;
use gtk::prelude::*;

#[derive(Clone, Copy)]
pub enum PowerAction {
    Restart,
    PowerOff,
}

pub async fn request(action: PowerAction) -> Result<(), glib::Error> {
    let method = match action {
        PowerAction::Restart => "Reboot",
        PowerAction::PowerOff => "PowerOff",
    };
    let interactive = false;
    let bus = gio::bus_get_future(gio::BusType::System).await?;
    bus.call_future(
        Some("org.freedesktop.login1"),
        "/org/freedesktop/login1",
        "org.freedesktop.login1.Manager",
        method,
        Some(&(interactive,).to_variant()),
        None,
        gio::DBusCallFlags::NONE,
        -1,
    )
    .await?;
    Ok(())
}
