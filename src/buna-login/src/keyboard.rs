//! The on-screen keyboard, for touchscreens without a keyboard: it slides
//! up from the bottom when a field is tapped with a finger, or from the
//! bar's keyboard button.  English (with shift) and Arabic letters, a row
//! of digits, and a page of symbols, since passwords use them.  The screen
//! decides which field a key goes to (`type_into` types it there) and what
//! Enter does.
//!
//! The keys keep their places whatever the screen's language: an Arabic
//! keyboard has its letters where QWERTY has its own, so the rows are
//! always laid out left to right.

use std::cell::RefCell;
use std::rc::Rc;

use gtk::prelude::*;

use crate::text::Language;

#[derive(Clone)]
pub enum Key {
    Text(String),
    Backspace,
    Enter,
}

/// Rows of keys, separated by spaces (so "لا", two letters, is one key).
const DIGITS: &str = "1 2 3 4 5 6 7 8 9 0";
const ENGLISH: [&str; 3] = ["q w e r t y u i o p", "a s d f g h j k l", "z x c v b n m"];
/// The Arabic PC layout: ض on Q, ش on A, ئ on Z; ذ, on the key left of 1,
/// joins the third row.
const ARABIC: [&str; 3] = [
    "ض ص ث ق ف غ ع ه خ ح ج د",
    "ش س ي ب ل ا ت ن م ك ط",
    "ذ ئ ء ؤ ر لا ى ة و ز ظ",
];
const SYMBOLS: [&str; 3] = [
    "! @ # $ % ^ & * ( )",
    "- _ = + [ ] { } ; :",
    "' \" , . / ? \\ | ` ~ < >",
];

#[derive(Clone, Copy, PartialEq)]
enum Page {
    Letters,
    Capitals,
    Symbols,
}

/// What pressing a key does: a `Key` goes to the screen, the rest change
/// the keyboard.
#[derive(Clone)]
enum Press {
    Key(Key),
    Shift,
    ShowPage(Page),
    OtherLanguage,
}

pub struct Keyboard {
    /// Hidden until `show`; goes at the bottom of the screen.
    pub widget: gtk::Revealer,
    state: Rc<State>,
}

type OnKey = Box<dyn Fn(Key)>;

struct State {
    rows: gtk::Box,
    language: RefCell<Language>,
    page: RefCell<Page>,
    on_key: RefCell<Option<OnKey>>,
}

impl Keyboard {
    pub fn new(language: Language) -> Keyboard {
        let rows = gtk::Box::new(gtk::Orientation::Vertical, 6);
        rows.add_css_class("keyboard");
        rows.set_halign(gtk::Align::Center);
        rows.set_direction(gtk::TextDirection::Ltr);

        let widget = gtk::Revealer::builder()
            .transition_type(gtk::RevealerTransitionType::SlideUp)
            .child(&rows)
            .build();
        let state = Rc::new(State {
            rows,
            language: RefCell::new(language),
            page: RefCell::new(Page::Letters),
            on_key: RefCell::new(None),
        });
        fill(&state);
        Keyboard { widget, state }
    }

    /// What to do with each key typed; set once, by the screen.
    pub fn connect_key(&self, on_key: impl Fn(Key) + 'static) {
        self.state.on_key.replace(Some(Box::new(on_key)));
    }

    /// Opens the keyboard when `field` is touched with a finger; a mouse or
    /// a keyboard leaves it closed.
    pub fn open_on_touch(&self, field: &impl IsA<gtk::Widget>) {
        let tap = gtk::GestureClick::new();
        tap.set_touch_only(true);
        // Before the field's own handling, which would otherwise take the tap
        tap.set_propagation_phase(gtk::PropagationPhase::Capture);
        let widget = self.widget.clone();
        tap.connect_pressed(move |_, _, _, _| widget.set_reveal_child(true));
        field.add_controller(tap);
    }

    pub fn toggle(&self) {
        let shown = self.widget.reveals_child();
        self.widget.set_reveal_child(!shown);
    }
}

/// Builds the keys for the current language and page, replacing any there.
fn fill(state: &Rc<State>) {
    while let Some(row) = state.rows.first_child() {
        state.rows.remove(&row);
    }
    let language = *state.language.borrow();
    let page = *state.page.borrow();

    let letters = match (page, language) {
        (Page::Symbols, _) => SYMBOLS,
        (_, Language::English) => ENGLISH,
        (_, Language::Arabic) => ARABIC,
    };
    let capitals = page == Page::Capitals;

    let digits = row();
    add_typing_keys(state, &digits, DIGITS, false);
    state.rows.append(&digits);

    for (index, keys) in letters.iter().enumerate() {
        let row = row();
        let is_last = index == letters.len() - 1;
        // Shift only for English letters: Arabic has no capitals
        let has_shift = is_last && page != Page::Symbols && language == Language::English;
        if has_shift {
            let shift = key(state, "⇧", Press::Shift, "special");
            if capitals {
                shift.add_css_class("on");
            }
            row.append(&shift);
        }
        add_typing_keys(state, &row, keys, capitals);
        if is_last {
            row.append(&key(state, "⌫", Press::Key(Key::Backspace), "special"));
        }
        state.rows.append(&row);
    }

    state.rows.append(&bottom_row(state, page, language));
}

/// Letters or symbols, the other language, space, enter.
fn bottom_row(state: &Rc<State>, page: Page, language: Language) -> gtk::Box {
    let bottom = row();
    let page_key = match (page, language) {
        (Page::Symbols, Language::English) => key(state, "ABC", Press::ShowPage(Page::Letters), "special"),
        (Page::Symbols, Language::Arabic) => key(state, "أبج", Press::ShowPage(Page::Letters), "special"),
        _ => key(state, "?123", Press::ShowPage(Page::Symbols), "special"),
    };
    let language_key = match language {
        Language::English => key(state, "ع", Press::OtherLanguage, "special"),
        Language::Arabic => key(state, "EN", Press::OtherLanguage, "special"),
    };
    let space = key(state, "", Press::Key(Key::Text(" ".into())), "space");
    space.set_hexpand(true);
    bottom.append(&page_key);
    bottom.append(&language_key);
    bottom.append(&space);
    bottom.append(&key(state, "↵", Press::Key(Key::Enter), "special"));
    bottom.set_halign(gtk::Align::Fill);
    bottom
}

/// Left to right whatever the screen's language: a widget without a
/// direction of its own takes the default one (right to left in Arabic),
/// not its parent's.
fn row() -> gtk::Box {
    let row = gtk::Box::new(gtk::Orientation::Horizontal, 6);
    row.set_halign(gtk::Align::Center);
    row.set_direction(gtk::TextDirection::Ltr);
    row
}

fn add_typing_keys(state: &Rc<State>, row: &gtk::Box, keys: &str, capitals: bool) {
    for text in keys.split_whitespace() {
        let text = if capitals { text.to_uppercase() } else { text.to_string() };
        row.append(&key(state, &text, Press::Key(Key::Text(text.clone())), "letter"));
    }
}

/// A key never takes the focus, so what it types goes to the field that
/// has it.
fn key(state: &Rc<State>, label: &str, press: Press, class: &str) -> gtk::Button {
    let button = gtk::Button::with_label(label);
    button.add_css_class("key");
    button.add_css_class(class);
    button.set_focusable(false);
    button.set_focus_on_click(false);
    let state = state.clone();
    button.connect_clicked(move |_| pressed(&state, press.clone()));
    button
}

fn pressed(state: &Rc<State>, press: Press) {
    match press {
        Press::Key(key) => {
            let is_letter = matches!(key, Key::Text(_));
            report(state, key);
            // Shift lasts for one letter, as on a phone
            if is_letter && *state.page.borrow() == Page::Capitals {
                show_page(state, Page::Letters);
            }
        }
        Press::Shift => {
            let page = if *state.page.borrow() == Page::Capitals { Page::Letters } else { Page::Capitals };
            show_page(state, page);
        }
        Press::ShowPage(page) => show_page(state, page),
        Press::OtherLanguage => {
            let other = state.language.borrow().other();
            state.language.replace(other);
            show_page(state, Page::Letters);
        }
    }
}

fn show_page(state: &Rc<State>, page: Page) {
    state.page.replace(page);
    fill(state);
}

fn report(state: &Rc<State>, key: Key) {
    if let Some(on_key) = state.on_key.borrow().as_ref() {
        on_key(key);
    }
}

/// Types `key` into `field` as a real keyboard would: over the selection if
/// there is one.  Enter is not typed; what it does is the screen's choice.
pub fn type_into(field: &gtk::Editable, key: &Key) {
    match key {
        Key::Text(text) => {
            field.delete_selection();
            let mut position = field.position();
            field.insert_text(text, &mut position);
            field.set_position(position);
        }
        Key::Backspace => {
            if field.selection_bounds().is_some() {
                field.delete_selection();
                return;
            }
            let position = field.position();
            if position > 0 {
                field.delete_text(position - 1, position);
            }
        }
        Key::Enter => {}
    }
}

/// Shows `widget` only while there is a touchscreen to use the keyboard
/// with, one plugged in later included.
pub fn show_with_touchscreen(widget: &impl IsA<gtk::Widget>) {
    let seat = gtk::gdk::Display::default().and_then(|display| display.default_seat());
    let Some(seat) = seat else {
        widget.set_visible(false);
        return;
    };
    let update = {
        let widget = widget.clone().upcast::<gtk::Widget>();
        move |seat: &gtk::gdk::Seat| {
            let has_touchscreen = seat.capabilities().contains(gtk::gdk::SeatCapabilities::TOUCH);
            widget.set_visible(has_touchscreen);
        }
    };
    update(&seat);
    let on_removed = update.clone();
    seat.connect_device_added(move |seat, _| update(seat));
    seat.connect_device_removed(move |seat, _| on_removed(seat));
}
