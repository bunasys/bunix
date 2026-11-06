//! The people who can log in at this screen: accounts in /etc/passwd with a
//! user id in the range useradd gives people (system accounts like root,
//! greeter or nobody fall outside it) and a shell to log in to.  When there
//! is exactly one, the screen asks only for their password.

pub struct Person {
    /// What they log in as.
    pub user_name: String,
    /// What the screen calls them: the account's full name, or the user
    /// name when it has none.
    pub display_name: String,
}

/// useradd's range for people's accounts (login.defs: UID_MIN, UID_MAX).
const FIRST_PERSON_UID: u32 = 1000;
const LAST_PERSON_UID: u32 = 60000;

/// Unreadable or unparsable lines just mean nobody is offered: the screen
/// then asks for a user name, which always works.
pub fn people() -> Vec<Person> {
    let Ok(passwd) = std::fs::read_to_string("/etc/passwd") else {
        return Vec::new();
    };
    passwd.lines().filter_map(person).collect()
}

/// One /etc/passwd line: name:password:uid:gid:full name,office,...:home:shell
fn person(line: &str) -> Option<Person> {
    let fields: Vec<&str> = line.split(':').collect();
    let [user_name, _, uid, _, comment, _, shell] = fields[..] else {
        return None;
    };
    let uid: u32 = uid.parse().ok()?;

    let is_person = (FIRST_PERSON_UID..=LAST_PERSON_UID).contains(&uid);
    let can_log_in = !shell.ends_with("/nologin") && !shell.ends_with("/false");
    if !is_person || !can_log_in {
        return None;
    }

    let full_name = comment.split(',').next().unwrap_or("").trim();
    let display_name = if full_name.is_empty() { user_name } else { full_name };
    Some(Person {
        user_name: user_name.to_string(),
        display_name: display_name.to_string(),
    })
}
