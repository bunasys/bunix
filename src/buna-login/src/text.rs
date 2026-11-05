//! Everything the login screen says, in English and Arabic.  The voice is
//! the Banan Design System's: plain, specific, sentence case, no
//! exclamation marks; Arabic translates the meaning, not the words.

#[derive(Clone, Copy, PartialEq)]
pub enum Language {
    English,
    Arabic,
}

impl Language {
    /// The language the greeter was started in ($LANG), English otherwise.
    pub fn from_environment() -> Language {
        let lang = std::env::var("LANG").unwrap_or_default();
        if lang.starts_with("ar") {
            return Language::Arabic;
        }
        Language::English
    }

    pub fn is_right_to_left(self) -> bool {
        self == Language::Arabic
    }

    /// The other language, which the switch on the screen offers.
    pub fn other(self) -> Language {
        match self {
            Language::English => Language::Arabic,
            Language::Arabic => Language::English,
        }
    }
}

pub struct Text {
    pub title: String,
    pub user_name: &'static str,
    pub password: &'static str,
    pub log_in: &'static str,
    pub checking: &'static str,
    pub wrong_password: &'static str,
    pub needs_more: &'static str,
    pub failed: &'static str,
    pub restart: &'static str,
    pub power_off: &'static str,
    /// The switch's label, written in the language it switches to.
    pub other_language: &'static str,
}

pub fn text(language: Language, host_name: &str) -> Text {
    match language {
        Language::English => Text {
            title: format!("Log in to {host_name}"),
            user_name: "User name",
            password: "Password",
            log_in: "Log in",
            checking: "Checking…",
            wrong_password: "That user name and password don't match.",
            needs_more: "This account needs more than a password. Log in on a console (Ctrl+Alt+F2).",
            failed: "Could not log in:",
            restart: "Restart",
            power_off: "Power off",
            other_language: "العربية",
        },
        Language::Arabic => Text {
            title: format!("تسجيل الدخول إلى {host_name}"),
            user_name: "اسم المستخدم",
            password: "كلمة المرور",
            log_in: "دخول",
            checking: "جارٍ التحقق…",
            wrong_password: "اسم المستخدم وكلمة المرور غير متطابقين.",
            needs_more: "يتطلب هذا الحساب أكثر من كلمة مرور. سجّل الدخول من الطرفية (Ctrl+Alt+F2).",
            failed: "تعذّر تسجيل الدخول:",
            restart: "إعادة التشغيل",
            power_off: "إيقاف التشغيل",
            other_language: "English",
        },
    }
}
