//! buna-login: bunix's login screen.  greetd runs it as its greeter, inside a
//! one-window Hyprland (/usr/share/buna-login/hyprland.lua); it asks for a
//! user name and password, has greetd check them (greetd.rs), and quits so
//! greetd can start the user's session.  Styled with the Banan Design
//! System (style.css), light or dark as the system prefers; English or
//! Arabic, right to left in Arabic, switchable on the screen.

mod greetd;
mod power;
mod text;

use adw::prelude::*;
use gtk::gio;
use gtk::glib;

use greetd::LoginError;
use text::{Language, Text};

/// What a successful login starts: Hyprland, through its watchdog.
const SESSION: &[&str] = &["start-hyprland"];
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

/// Builds the whole screen in `language` and puts it in the window.  The
/// language switch calls this again, so nothing has to be relabelled.
fn show_screen(window: &adw::ApplicationWindow, language: Language) {
    let direction = if language.is_right_to_left() {
        gtk::TextDirection::Rtl
    } else {
        gtk::TextDirection::Ltr
    };
    gtk::Widget::set_default_direction(direction);
    if language.is_right_to_left() {
        window.add_css_class("arabic");
    } else {
        window.remove_css_class("arabic");
    }

    let host_name = glib::host_name();
    let text = text::text(language, &host_name);

    // The card in the middle: logo, title, the two fields, the message
    // line, the button
    let logo = gtk::Picture::for_filename(LOGO);
    logo.set_can_shrink(true);
    logo.set_size_request(56, 56);
    logo.set_halign(gtk::Align::Start);
    logo.add_css_class("logo");

    let title = label(&text.title, "title");

    let user_name = gtk::Entry::builder()
        .placeholder_text(text.user_name)
        .input_purpose(gtk::InputPurpose::FreeForm)
        .build();
    let password = gtk::PasswordEntry::builder()
        .placeholder_text(text.password)
        .show_peek_icon(true)
        .build();
    let message = label("", "message");
    message.set_wrap(true);
    message.set_visible(false);
    let log_in = gtk::Button::with_label(text.log_in);
    log_in.add_css_class("primary");

    let card = gtk::Box::new(gtk::Orientation::Vertical, 0);
    card.add_css_class("card");
    card.set_halign(gtk::Align::Center);
    card.set_valign(gtk::Align::Center);
    card.set_vexpand(true);
    for widget in [
        logo.upcast_ref::<gtk::Widget>(),
        title.upcast_ref(),
        label(text.user_name, "field-label").upcast_ref(),
        user_name.upcast_ref(),
        label(text.password, "field-label").upcast_ref(),
        password.upcast_ref(),
        message.upcast_ref(),
        log_in.upcast_ref(),
    ] {
        card.append(widget);
    }

    // The bottom bar: the language switch at the start, power at the end
    let switch_language = gtk::Button::with_label(text.other_language);
    switch_language.add_css_class("quiet");
    let restart = gtk::Button::with_label(text.restart);
    restart.add_css_class("secondary");
    let power_off = gtk::Button::with_label(text.power_off);
    power_off.add_css_class("secondary");

    let bar = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    bar.add_css_class("bar");
    let spacer = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    spacer.set_hexpand(true);
    bar.append(&switch_language);
    bar.append(&spacer);
    bar.append(&restart);
    bar.append(&power_off);

    let screen = gtk::Box::new(gtk::Orientation::Vertical, 0);
    screen.add_css_class("screen");
    screen.append(&card);
    screen.append(&bar);
    window.set_content(Some(&screen));

    // Behaviour
    let form = Form { user_name, password, log_in, message, text };
    form.user_name.grab_focus();
    {
        let password = form.password.clone();
        form.user_name.connect_activate(move |_| {
            password.grab_focus();
        });
    }
    let form = std::rc::Rc::new(form);
    {
        let form = form.clone();
        form.password.clone().connect_activate(move |_| form.submit());
    }
    {
        let form = form.clone();
        form.log_in.clone().connect_clicked(move |_| form.submit());
    }
    {
        let window = window.clone();
        switch_language.connect_clicked(move |_| show_screen(&window, language.other()));
    }
    {
        let form = form.clone();
        restart.connect_clicked(move |_| form.power(power::PowerAction::Restart));
    }
    power_off.connect_clicked(move |_| form.power(power::PowerAction::PowerOff));
}

fn label(text: &str, class: &str) -> gtk::Label {
    let label = gtk::Label::new(Some(text));
    label.set_halign(gtk::Align::Start);
    label.add_css_class(class);
    label
}

/// The fields and the line under them, with what the screen says.
struct Form {
    user_name: gtk::Entry,
    password: gtk::PasswordEntry,
    log_in: gtk::Button,
    message: gtk::Label,
    text: Text,
}

impl Form {
    /// Checks the password with greetd off the main thread (a wrong one
    /// takes PAM's two-second delay), then quits on success, so greetd
    /// starts the session, or says what went wrong.
    fn submit(self: &std::rc::Rc<Self>) {
        let user_name = self.user_name.text().trim().to_string();
        let password = self.password.text().to_string();
        if user_name.is_empty() {
            self.user_name.grab_focus();
            return;
        }

        self.set_busy(true);
        let form = self.clone();
        let check = gio::spawn_blocking(move || greetd::log_in(&user_name, &password, SESSION));
        glib::spawn_future_local(async move {
            let result = check.await.unwrap_or_else(|_| {
                Err(LoginError::Failed("the login check stopped unexpectedly".into()))
            });
            form.set_busy(false);
            match result {
                Ok(()) => {
                    if let Some(app) = gio::Application::default() {
                        app.quit();
                    }
                }
                Err(error) => form.show_error(error),
            }
        });
    }

    fn show_error(&self, error: LoginError) {
        let message = match error {
            LoginError::WrongPassword => self.text.wrong_password.to_string(),
            LoginError::NeedsMore => self.text.needs_more.to_string(),
            LoginError::Failed(reason) => format!("{} {reason}", self.text.failed),
        };
        self.message.set_text(&message);
        self.message.set_visible(true);
        self.password.add_css_class("invalid");
        self.password.set_text("");
        self.password.grab_focus();
    }

    fn set_busy(&self, busy: bool) {
        self.user_name.set_sensitive(!busy);
        self.password.set_sensitive(!busy);
        self.log_in.set_sensitive(!busy);
        let label = if busy { self.text.checking } else { self.text.log_in };
        self.log_in.set_label(label);
        if busy {
            self.message.set_visible(false);
            self.password.remove_css_class("invalid");
        }
    }

    fn power(&self, action: power::PowerAction) {
        if let Err(error) = power::request(action) {
            self.message.set_text(&format!("{} {error}", self.text.failed));
            self.message.set_visible(true);
        }
    }
}
