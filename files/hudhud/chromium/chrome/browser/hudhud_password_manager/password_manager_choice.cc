// Hudhud's password manager choice (bunix: docs/browser.md, "Password manager").

#include "chrome/browser/hudhud_password_manager/password_manager_choice.h"

#include "components/pref_registry/pref_registry_syncable.h"
#include "components/prefs/pref_service.h"

namespace hudhud_password_manager {

void RegisterProfilePrefs(user_prefs::PrefRegistrySyncable* registry) {
  registry->RegisterStringPref(kChoicePref, kBuiltIn);
}

bool IsBuiltInPasswordManagerChosen(const PrefService* prefs) {
  // Profiles without prefs (none in practice) keep Chromium's behaviour.
  if (!prefs) {
    return true;
  }
  return prefs->GetString(kChoicePref) == kBuiltIn;
}

}  // namespace hudhud_password_manager
