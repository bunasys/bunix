//! buna-login: bunix's login screen.  greetd runs it as its greeter, inside a
//! one-window Hyprland (data/hyprland.lua); it asks for a user name and
//! password, has greetd check them (greetd.rs), and quits so greetd can
//! start the user's session.  Styled with the Banan Design System
//! (style.css), light or dark as the system prefers; English or Arabic,
//! right to left in Arabic, switchable on the screen.

mod greetd;
mod power;
mod text;

use std::rc::Rc;

use adw::prelude::*;
use gtk::gio;
use gtk::glib;

use greetd::LoginError;
use power::PowerAction;
use text::{Language, Text};

/// What a successful login starts: Hyprland, through its watchdog.
const SESSION: &[&str] = &["start-hyprland"];
/// Added to the session's environment before logind registers it, so the
/// login shows as a Wayland desktop session, not a text console one.
const SESSION_ENV: &[&str] = &["XDG_SESSION_TYPE=wayland", "XDG_CURRENT_DESKTOP=Hyprland"];
const LOGO: &str = "/usr/share/buna-login/buna-logo.svg";

fn main() -> glib::ExitCode {
    let app = adw::Application::builder()
        .application_id("org.bunasys.BunaLogin")
        .build();
    app.connect_startup(|_| load_style());
    app.connect_activate(|app| {
        let window = adw::ApplicationWindow::builder()
            .application(app)
            .title("buna-login")
            .build();
        window.add_css_class("buna-login");
        follow_color_scheme(&window);
        show_screen(&window, Language::from_environment());
        window.fullscreen();
        window.present();
    });
    app.run()
}

fn load_style() {
    let css = gtk::CssProvider::new();
    css.load_from_string(include_str!("style.css"));
    let display = gtk::gdk::Display::default().expect("a display to log in on");
    gtk::style_context_add_provider_for_display(
        &display,
        &css,
        gtk::STYLE_PROVIDER_PRIORITY_APPLICATION,
    );
}

/// style.css keeps both themes' colors; the "dark" class picks the dark ones.
fn follow_color_scheme(window: &adw::ApplicationWindow) {
    let style = adw::StyleManager::default();
    let apply = {
        let window = window.clone();
        move |style: &adw::StyleManager| {
            if style.is_dark() {
                window.add_css_class("dark");
            } else {
                window.remove_css_class("dark");
            }
        }
    };
    apply(&style);
    style.connect_dark_notify(apply);
}

/// Puts the whole screen, in `language`, into the window.  The language
/// switch calls this again, so nothing has to be relabelled.
fn show_screen(window: &adw::ApplicationWindow, language: Language) {
    if language.is_right_to_left() {
        gtk::Widget::set_default_direction(gtk::TextDirection::Rtl);
        window.add_css_class("arabic");
    } else {
        gtk::Widget::set_default_direction(gtk::TextDirection::Ltr);
        window.remove_css_class("arabic");
    }

    let screen = Rc::new(Screen::build(Text::new(language, &glib::host_name())));
    window.set_content(Some(&screen.root));
    connect(&screen, window, language);
    screen.user_name.grab_focus();
}

/// The screen's widgets that change after it is built, and what it says.
struct Screen {
    root: gtk::Box,
    user_name: gtk::Entry,
    password: gtk::PasswordEntry,
    log_in: gtk::Button,
    message: gtk::Label,
    switch_language: gtk::Button,
    restart: gtk::Button,
    power_off: gtk::Button,
    text: Text,
}

impl Screen {
    /// The card in the middle (logo, title, the two fields, the message
    /// line, the button) and the bar at the bottom (the language switch at
    /// the start, restart and power off at the end).
    fn build(text: Text) -> Screen {
        let logo = gtk::Picture::for_filename(LOGO);
        logo.set_can_shrink(true);
        logo.set_size_request(56, 56);
        logo.set_halign(gtk::Align::Start);
        logo.add_css_class("logo");

        let user_name = gtk::Entry::builder().placeholder_text(text.user_name).build();
        let password = gtk::PasswordEntry::builder()
            .placeholder_text(text.password)
            .show_peek_icon(true)
            .build();
        let message = label("", "message");
        message.set_wrap(true);
        message.set_visible(false);
        let log_in = button(text.log_in, "primary");

        let card = gtk::Box::new(gtk::Orientation::Vertical, 0);
        card.add_css_class("card");
        card.set_halign(gtk::Align::Center);
        card.set_valign(gtk::Align::Center);
        card.set_vexpand(true);
        card.append(&logo);
        card.append(&label(&text.title, "title"));
        card.append(&label(text.user_name, "field-label"));
        card.append(&user_name);
        card.append(&label(text.password, "field-label"));
        card.append(&password);
        card.append(&message);
        card.append(&log_in);

        let switch_language = button(text.other_language, "quiet");
        let restart = button(text.restart, "secondary");
        let power_off = button(text.power_off, "secondary");
        let spacer = gtk::Box::new(gtk::Orientation::Horizontal, 0);
        spacer.set_hexpand(true);
        let bar = gtk::Box::new(gtk::Orientation::Horizontal, 8);
        bar.add_css_class("bar");
        bar.append(&switch_language);
        bar.append(&spacer);
        bar.append(&restart);
        bar.append(&power_off);

        let root = gtk::Box::new(gtk::Orientation::Vertical, 0);
        root.add_css_class("screen");
        root.append(&card);
        root.append(&bar);

        Screen { root, user_name, password, log_in, message, switch_language, restart, power_off, text }
    }

    /// Nothing on the screen can be pressed while a check runs: a second
    /// login would make greetd cancel the first, and the language switch
    /// would build a screen the running check knows nothing about.
    fn set_busy(&self, busy: bool) {
        let controls: [&gtk::Widget; 6] = [
            self.user_name.upcast_ref(),
            self.password.upcast_ref(),
            self.log_in.upcast_ref(),
            self.switch_language.upcast_ref(),
            self.restart.upcast_ref(),
            self.power_off.upcast_ref(),
        ];
        for control in controls {
            control.set_sensitive(!busy);
        }
        let label = if busy { self.text.checking } else { self.text.log_in };
        self.log_in.set_label(label);
    }

    fn show_error(&self, message: &str) {
        self.message.set_text(message);
        self.message.set_visible(true);
    }

    fn clear_error(&self) {
        self.message.set_visible(false);
        self.password.remove_css_class("invalid");
    }
}

fn label(text: &str, class: &str) -> gtk::Label {
    let label = gtk::Label::new(Some(text));
    label.set_halign(gtk::Align::Start);
    label.add_css_class(class);
    label
}

fn button(text: &str, class: &str) -> gtk::Button {
    let button = gtk::Button::with_label(text);
    button.add_css_class(class);
    button
}

/// What each control does.  Enter in the user name moves to the password;
/// Enter there, or the button, logs in.
fn connect(screen: &Rc<Screen>, window: &adw::ApplicationWindow, language: Language) {
    let password = screen.password.clone();
    screen.user_name.connect_activate(move |_| {
        password.grab_focus();
    });

    let on_enter = screen.clone();
    screen.password.connect_activate(move |_| log_in(&on_enter));
    let on_click = screen.clone();
    screen.log_in.connect_clicked(move |_| log_in(&on_click));

    let window = window.clone();
    screen.switch_language.connect_clicked(move |_| show_screen(&window, language.other()));

    let on_restart = screen.clone();
    screen.restart.connect_clicked(move |_| power(&on_restart, PowerAction::Restart));
    let on_power_off = screen.clone();
    screen.power_off.connect_clicked(move |_| power(&on_power_off, PowerAction::PowerOff));
}

/// Checks the password with greetd off the main thread (a wrong one takes
/// PAM's two-second delay), then quits on success, so greetd starts the
/// session, or says what went wrong.
fn log_in(screen: &Rc<Screen>) {
    let user_name = screen.user_name.text().trim().to_string();
    let password = screen.password.text().to_string();
    if user_name.is_empty() {
        screen.user_name.grab_focus();
        return;
    }

    screen.clear_error();
    screen.set_busy(true);
    let screen = screen.clone();
    let check = gio::spawn_blocking(move || {
        greetd::log_in(&user_name, &password, SESSION, SESSION_ENV)
    });
    glib::spawn_future_local(async move {
        let result = check.await.unwrap_or_else(|_| {
            Err(LoginError::Failed("the login check stopped unexpectedly".into()))
        });
        screen.set_busy(false);
        let error = match result {
            Ok(()) => {
                if let Some(app) = gio::Application::default() {
                    app.quit();
                }
                return;
            }
            Err(error) => error,
        };

        let text = &screen.text;
        let message = match error {
            LoginError::WrongPassword => text.wrong_password.to_string(),
            LoginError::NeedsMore => text.needs_more.to_string(),
            LoginError::Failed(reason) => format!("{} {reason}", text.failed),
        };
        screen.show_error(&message);
        screen.password.add_css_class("invalid");
        screen.password.set_text("");
        screen.password.grab_focus();
    });
}

/// Asks logind to restart or power off; only a refusal shows on screen.
fn power(screen: &Rc<Screen>, action: PowerAction) {
    screen.clear_error();
    let screen = screen.clone();
    glib::spawn_future_local(async move {
        let Err(error) = power::request(action).await else {
            return;
        };
        let prefix = match action {
            PowerAction::Restart => screen.text.restart_failed,
            PowerAction::PowerOff => screen.text.power_off_failed,
        };
        screen.show_error(&format!("{prefix} {}", error.message()));
    });
}
