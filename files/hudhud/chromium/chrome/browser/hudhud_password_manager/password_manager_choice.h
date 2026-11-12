// Hudhud's password manager choice (bunix: docs/browser.md, "Password manager").

#ifndef CHROME_BROWSER_HUDHUD_PASSWORD_MANAGER_PASSWORD_MANAGER_CHOICE_H_
#define CHROME_BROWSER_HUDHUD_PASSWORD_MANAGER_PASSWORD_MANAGER_CHOICE_H_

class PrefService;

namespace user_prefs {
class PrefRegistrySyncable;
}

namespace hudhud_password_manager {

// Who saves and fills the user's passwords: "builtin" (Hudhud's own password
// manager, the default), "off" (nobody), or the id of the password-manager
// extension the user chose (chrome://password-manager offers them).
inline constexpr char kChoicePref[] = "hudhud.password_manager";
inline constexpr char kBuiltIn[] = "builtin";
inline constexpr char kOff[] = "off";

void RegisterProfilePrefs(user_prefs::PrefRegistrySyncable* registry);

// Whether Hudhud's own password manager may offer to save and may fill
// passwords.  With an extension chosen it must do neither, or the user gets
// two password managers prompting on every sign-in form.
bool IsBuiltInPasswordManagerChosen(const PrefService* prefs);

}  // namespace hudhud_password_manager

#endif  // CHROME_BROWSER_HUDHUD_PASSWORD_MANAGER_PASSWORD_MANAGER_CHOICE_H_
