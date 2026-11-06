//! buna-login: bunix's login screen.  greetd runs it as its greeter, full
//! screen in cage (data/greetd.toml); it asks for a user name and
//! password, has greetd check them (greetd.rs), and quits so greetd can
//! start the user's session.  Styled with the Banan Design System
//! (style.css), light or dark as the system prefers; English or Arabic,
//! right to left in Arabic, switchable on the screen.  With only one person
//! who can log in (users.rs), it asks just for their password; on a
//! touchscreen it has its own keyboard (keyboard.rs).

mod greetd;
mod keyboard;
mod last_user;
mod power;
mod text;
mod users;

use std::rc::Rc;

use adw::prelude::*;
use gtk::gio;
use gtk::glib;

use greetd::LoginError;
use keyboard::{Key, Keyboard};
use power::PowerAction;
use text::{Language, Text};
use users::Person;

/// What a successful login starts: Hyprland, through its watchdog, with its
/// output in the journal rather than on the console behind it.
const SESSION: &[&str] = &["systemd-cat", "--identifier=hyprland", "start-hyprland"];
/// Added to the session's environment before logind registers it, so the
/// login shows as a Wayland desktop session, not a text console one.
const SESSION_ENV: &[&str] = &["XDG_SESSION_TYPE=wayland", "XDG_CURRENT_DESKTOP=Hyprland"];
const LOGO: &str = "/usr/share/buna-login/buna-logo.svg";
/// The card's width, and the logo's: fixed, whatever the screen's size.
const CARD_WIDTH: i32 = 360;
const LOGO_SIZE: i32 = 64;

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

    let people = users::people();
    let only_person = match people.as_slice() {
        [person] => Some(person),
        _ => None,
    };
    let text = Text::new(language, &glib::host_name());
    let screen = Rc::new(Screen::build(text, language, only_person));
    window.set_content(Some(&screen.root));
    connect(&screen, window, language);

    // The user name, when the screen can know it: the only person's, or
    // the last one to log in, who is likely the one at the screen now.
    // Then the password is what is left to type.
    let known_name = match only_person {
        Some(person) => Some(person.user_name.clone()),
        None => last_user::read(),
    };
    let Some(name) = known_name else {
        screen.user_name.grab_focus();
        return;
    };
    screen.user_name.set_text(&name);
    screen.password.grab_focus();
}

/// The screen's widgets that change after it is built, and what it says.
struct Screen {
    root: gtk::Box,
    title: gtk::Label,
    user_name_label: gtk::Label,
    user_name: gtk::Entry,
    password: gtk::PasswordEntry,
    log_in: gtk::Button,
    other_user: gtk::Button,
    message: gtk::Label,
    keyboard: Keyboard,
    show_keyboard: gtk::Button,
    switch_language: gtk::Button,
    restart: gtk::Button,
    power_off: gtk::Button,
    text: Text,
}

impl Screen {
    /// The card in the middle (logo, title, the two fields, the message
    /// line, the button), the on-screen keyboard below it, and the bar at
    /// the bottom (the language switch and the keyboard button at the
    /// start, restart and power off at the end).
    ///
    /// With `only_person`, the card is theirs: their name as its title, and
    /// no user name field to fill in, until "someone else" brings it back.
    fn build(text: Text, language: Language, only_person: Option<&Person>) -> Screen {
        // an Image, not a Picture: a Picture grows to the SVG's own size
        let logo = gtk::Image::from_file(LOGO);
        logo.set_pixel_size(LOGO_SIZE);
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
        let other_user = button(text.other_user, "quiet");
        other_user.add_css_class("other-user");
        let title = label(&text.title, "title");
        let user_name_label = label(text.user_name, "field-label");

        let card = gtk::Box::new(gtk::Orientation::Vertical, 0);
        card.add_css_class("card");
        card.set_size_request(CARD_WIDTH, -1);
        card.set_halign(gtk::Align::Center);
        card.set_valign(gtk::Align::Center);
        card.set_vexpand(true);
        card.append(&logo);
        card.append(&title);
        card.append(&user_name_label);
        card.append(&user_name);
        card.append(&label(text.password, "field-label"));
        card.append(&password);
        card.append(&message);
        card.append(&log_in);
        card.append(&other_user);
        // Their account may be locked, or someone else may need the machine
        other_user.set_visible(only_person.is_some());
        if let Some(person) = only_person {
            title.set_text(&person.display_name);
            user_name_label.set_visible(false);
            user_name.set_visible(false);
        }

        let keyboard = Keyboard::new(language);

        let switch_language = button(text.other_language, "quiet");
        // Only offered where there is a touchscreen to type on it with
        let show_keyboard = button(text.keyboard, "quiet");
        keyboard::show_with_touchscreen(&show_keyboard);
        // Keeps the focus in the field the keyboard is to type into
        show_keyboard.set_focus_on_click(false);
        let restart = button(text.restart, "secondary");
        let power_off = button(text.power_off, "secondary");
        let spacer = gtk::Box::new(gtk::Orientation::Horizontal, 0);
        spacer.set_hexpand(true);
        let bar = gtk::Box::new(gtk::Orientation::Horizontal, 8);
        bar.add_css_class("bar");
        bar.append(&switch_language);
        bar.append(&show_keyboard);
        bar.append(&spacer);
        bar.append(&restart);
        bar.append(&power_off);

        let root = gtk::Box::new(gtk::Orientation::Vertical, 0);
        root.add_css_class("screen");
        root.append(&card);
        root.append(&keyboard.widget);
        root.append(&bar);

        Screen {
            root,
            title,
            user_name_label,
            user_name,
            password,
            log_in,
            other_user,
            message,
            keyboard,
            show_keyboard,
            switch_language,
            restart,
            power_off,
            text,
        }
    }

    /// The field the on-screen keyboard types into: the user name while it
    /// has the focus, the password otherwise.
    fn typing_field(&self) -> gtk::Editable {
        let focus = self.root.root().and_then(|root| root.focus());
        let user_name_has_focus = focus.is_some_and(|focus| focus.is_ancestor(&self.user_name));
        if user_name_has_focus {
            return self.user_name.clone().upcast();
        }
        self.password.clone().upcast()
    }

    /// Nothing on the screen can be pressed while a check runs: a second
    /// login would make greetd cancel the first, and the language switch
    /// would build a screen the running check knows nothing about.
    fn set_busy(&self, busy: bool) {
        let controls: [&gtk::Widget; 8] = [
            self.user_name.upcast_ref(),
            self.password.upcast_ref(),
            self.log_in.upcast_ref(),
            self.other_user.upcast_ref(),
            self.keyboard.widget.upcast_ref(),
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

    /// The full form, for logging in as anyone: the general title and an
    /// empty user name field.
    fn ask_for_user_name(&self) {
        self.title.set_text(&self.text.title);
        self.user_name_label.set_visible(true);
        self.user_name.set_visible(true);
        self.user_name.set_text("");
        self.other_user.set_visible(false);
        self.clear_error();
        self.user_name.grab_focus();
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

    let on_other_user = screen.clone();
    screen.other_user.connect_clicked(move |_| on_other_user.ask_for_user_name());

    // The old screen is not freed (its widgets' handlers hold it), so the
    // password typed into it is cleared first
    let window = window.clone();
    let on_switch = screen.clone();
    screen.switch_language.connect_clicked(move |_| {
        on_switch.password.set_text("");
        show_screen(&window, language.other());
    });

    let on_restart = screen.clone();
    screen.restart.connect_clicked(move |_| power(&on_restart, PowerAction::Restart));
    let on_power_off = screen.clone();
    screen.power_off.connect_clicked(move |_| power(&on_power_off, PowerAction::PowerOff));

    // The on-screen keyboard: opened by a finger on either field, or by
    // the bar's button
    screen.keyboard.open_on_touch(&screen.user_name);
    screen.keyboard.open_on_touch(&screen.password);
    let on_toggle = screen.clone();
    screen.show_keyboard.connect_clicked(move |_| on_toggle.keyboard.toggle());
    let on_key = screen.clone();
    screen.keyboard.connect_key(move |key| type_key(&on_key, key));
}

/// A key from the on-screen keyboard: typed into the field with the focus,
/// and Enter does what it does on a real keyboard (`connect`).
fn type_key(screen: &Rc<Screen>, key: Key) {
    let field = screen.typing_field();
    let is_enter = matches!(key, Key::Enter);
    if !is_enter {
        keyboard::type_into(&field, &key);
        return;
    }
    let in_user_name = field == *screen.user_name.upcast_ref::<gtk::Editable>();
    if in_user_name {
        screen.password.grab_focus();
        return;
    }
    log_in(screen);
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
    let checked_name = user_name.clone();
    let check = gio::spawn_blocking(move || {
        greetd::log_in(&checked_name, &password, SESSION, SESSION_ENV)
    });
    glib::spawn_future_local(async move {
        let result = check.await.unwrap_or_else(|_| {
            Err(LoginError::Failed("the login check stopped unexpectedly".into()))
        });
        // On success the controls stay disabled: the screen is about to go,
        // and a second login now would cancel the session greetd is starting
        let error = match result {
            Ok(()) => {
                last_user::write(&user_name);
                if let Some(app) = gio::Application::default() {
                    app.quit();
                }
                return;
            }
            Err(error) => error,
        };
        screen.set_busy(false);

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
