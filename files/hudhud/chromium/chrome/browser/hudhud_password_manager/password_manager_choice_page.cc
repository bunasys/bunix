// Hudhud's password manager choice (bunix: docs/browser.md, "Password manager").

#include "chrome/browser/hudhud_password_manager/password_manager_choice_page.h"

#include <memory>
#include <string>
#include <utility>

#include "base/functional/bind.h"
#include "base/i18n/rtl.h"
#include "base/memory/raw_ptr.h"
#include "base/scoped_observation.h"
#include "base/values.h"
#include "chrome/browser/hudhud_password_manager/password_manager_choice.h"
#include "chrome/browser/profiles/profile.h"
#include "chrome/common/webui_url_constants.h"
#include "components/password_manager/core/common/password_manager_pref_names.h"
#include "components/prefs/pref_change_registrar.h"
#include "components/prefs/pref_service.h"
#include "content/public/browser/page_navigator.h"
#include "content/public/browser/web_contents.h"
#include "content/public/browser/web_ui.h"
#include "content/public/browser/web_ui_data_source.h"
#include "content/public/browser/web_ui_message_handler.h"
#include "extensions/browser/extension_registry.h"
#include "extensions/browser/extension_registry_observer.h"
#include "extensions/common/extension.h"
#include "extensions/common/extension_urls.h"
#include "ui/base/page_transition_types.h"
#include "ui/base/window_open_disposition.h"
#include "url/gurl.h"

namespace hudhud_password_manager {

namespace {

// The password-manager extensions Hudhud offers, in the order the page lists
// them.  Each is installed from the Chrome Web Store, and `page` is the
// extension's own full-tab page, the one its toolbar popup opens:
// - 1Password: its settings (the passwords themselves are in the popup and
//   in the 1Password app).
// - Bitwarden: its vault, as its "pop out" button opens it.
// - Proton Pass: its settings, the manifest's options page.
struct ExtensionPasswordManager {
  const char* id;
  const char* name;
  const char* page;
};

constexpr ExtensionPasswordManager kExtensionPasswordManagers[] = {
    {"aeblfdkhhhdcdjpifhhbdiojplfjncoa", "1Password",
     "app/app.html#/page/settings"},
    {"nngceckbapebfimnlniiiahkandclblb", "Bitwarden",
     "popup/index.html?uilocation=popout#/tabs/vault"},
    {"ghmbeldphafepmbegfdlkpapadhbakde", "Proton Pass", "settings.html"},
};

const ExtensionPasswordManager* FindExtensionPasswordManager(
    const std::string& id) {
  for (const ExtensionPasswordManager& manager : kExtensionPasswordManagers) {
    if (id == manager.id) {
      return &manager;
    }
  }
  return nullptr;
}

// The page's strings.  Hudhud is Arabic first, and its strings are not in
// Chromium's translation files, so both languages are here.  The extensions'
// names are put in for $1 as they are: they are brand names in both.
struct PageString {
  const char* id;
  const char* english;
  const char* arabic;
};

constexpr PageString kPageStrings[] = {
    {"hudhudPasswordManagerTitle", "Password manager", "مدير كلمات المرور"},
    {"hudhudPasswordManagerChoiceDescription",
     "Choose who saves your passwords and fills them in.",
     "اختر من يحفظ كلمات مرورك ويملؤها."},
    {"hudhudPasswordManagerBuiltIn", "Hudhud's password manager",
     "مدير كلمات المرور في هدهد"},
    {"hudhudPasswordManagerOff", "None: turn off password management",
     "لا شيء: إيقاف إدارة كلمات المرور"},
    {"hudhudPasswordManagerInExtensionTitle", "Your passwords are in $1",
     "كلمات مرورك في $1"},
    {"hudhudPasswordManagerInExtensionDescription",
     "$1 saves and fills in your passwords and passkeys. Hudhud doesn't offer "
     "to save passwords or fill them in.",
     "يحفظ $1 كلمات مرورك ومفاتيح مرورك ويملؤها، ولا يعرض هدهد حفظ كلمات "
     "المرور أو ملأها."},
    {"hudhudPasswordManagerOpen", "Open $1", "فتح $1"},
    {"hudhudPasswordManagerNotInstalled", "$1 isn't installed yet.",
     "لم يُثبَّت $1 بعد."},
    {"hudhudPasswordManagerInstall", "Install $1", "تثبيت $1"},
    {"hudhudPasswordManagerDisabled", "$1 is turned off in Extensions.",
     "الإضافة $1 متوقفة في صفحة الإضافات."},
    {"hudhudPasswordManagerTurnOn", "Turn on $1", "تشغيل $1"},
    {"hudhudPasswordManagerOffTitle", "Password management is off",
     "إدارة كلمات المرور متوقفة"},
    {"hudhudPasswordManagerOffDescription",
     "Hudhud doesn't offer to save passwords or fill them in.",
     "لا يعرض هدهد حفظ كلمات المرور ولا يملؤها."},
    {"hudhudPasswordManagerSavedPasswordsKept",
     "Passwords you saved in Hudhud stay on this device. To use them again, "
     "choose Hudhud's password manager below.",
     "تبقى كلمات المرور التي حفظتها في هدهد على هذا الجهاز. لاستخدامها من "
     "جديد، اختر مدير كلمات المرور في هدهد أدناه."},
};

// Answers the <hudhud-password-manager-choice> element: what is chosen and
// which of the offered extensions are installed, and changes the choice.  It
// tells the page again whenever either changes, so every open
// chrome://password-manager tab stays right, even when the user installs the
// extension in another tab.
class ChoiceHandler : public content::WebUIMessageHandler,
                      public extensions::ExtensionRegistryObserver {
 public:
  explicit ChoiceHandler(Profile* profile) : profile_(profile) {}
  ChoiceHandler(const ChoiceHandler&) = delete;
  ChoiceHandler& operator=(const ChoiceHandler&) = delete;
  ~ChoiceHandler() override = default;

  void RegisterMessages() override {
    web_ui()->RegisterMessageCallback(
        "hudhudGetPasswordManagerChoice",
        base::BindRepeating(&ChoiceHandler::HandleGetChoice,
                            base::Unretained(this)));
    web_ui()->RegisterMessageCallback(
        "hudhudSetPasswordManagerChoice",
        base::BindRepeating(&ChoiceHandler::HandleSetChoice,
                            base::Unretained(this)));
    web_ui()->RegisterMessageCallback(
        "hudhudOpenPasswordManager",
        base::BindRepeating(&ChoiceHandler::HandleOpenPasswordManager,
                            base::Unretained(this)));
  }

  void OnJavascriptAllowed() override {
    pref_change_registrar_.Init(profile_->GetPrefs());
    pref_change_registrar_.Add(
        kChoicePref,
        base::BindRepeating(&ChoiceHandler::SendState, base::Unretained(this)));
    registry_observation_.Observe(extensions::ExtensionRegistry::Get(profile_));
  }

  void OnJavascriptDisallowed() override {
    pref_change_registrar_.RemoveAll();
    registry_observation_.Reset();
  }

  // extensions::ExtensionRegistryObserver: installing, uninstalling, turning
  // on and turning off an extension each end in one of these.
  void OnExtensionLoaded(content::BrowserContext* browser_context,
                         const extensions::Extension* extension) override {
    SendState();
  }
  void OnExtensionUnloaded(content::BrowserContext* browser_context,
                           const extensions::Extension* extension,
                           extensions::UnloadedExtensionReason reason) override {
    SendState();
  }
  void OnExtensionInstalled(content::BrowserContext* browser_context,
                            const extensions::Extension* extension,
                            bool is_update) override {
    SendState();
  }
  void OnExtensionUninstalled(content::BrowserContext* browser_context,
                              const extensions::Extension* extension,
                              extensions::UninstallReason reason) override {
    SendState();
  }

 private:
  // {choice: "builtin" | "off" | extension id,
  //  managers: [{id, name, installed, enabled}, ...]}
  base::DictValue GetState() const {
    auto* registry = extensions::ExtensionRegistry::Get(profile_);
    base::ListValue managers;
    for (const ExtensionPasswordManager& manager : kExtensionPasswordManagers) {
      bool installed = registry->GetInstalledExtension(manager.id) != nullptr;
      bool enabled = registry->enabled_extensions().Contains(manager.id);
      managers.Append(base::DictValue()
                          .Set("id", manager.id)
                          .Set("name", manager.name)
                          .Set("installed", installed)
                          .Set("enabled", enabled));
    }
    return base::DictValue()
        .Set("choice", profile_->GetPrefs()->GetString(kChoicePref))
        .Set("managers", std::move(managers));
  }

  void SendState() {
    FireWebUIListener("hudhud-password-manager-changed", GetState());
  }

  // args: [the page's callback id].  A page that sends anything else gets
  // nothing back rather than crashing the browser.
  void HandleGetChoice(const base::ListValue& args) {
    if (args.size() != 1) {
      return;
    }
    AllowJavascript();
    const base::Value& callback_id = args[0];
    ResolveJavascriptCallback(callback_id, GetState());
  }

  // args: ["builtin" | "off" | the id of an offered extension]
  void HandleSetChoice(const base::ListValue& args) {
    // The page could be compromised: only the choices it offers are taken.
    if (args.size() != 1 || !args[0].is_string()) {
      return;
    }
    const std::string& choice = args[0].GetString();
    bool is_built_in = choice == kBuiltIn;
    bool is_off = choice == kOff;
    bool is_offered_extension = FindExtensionPasswordManager(choice) != nullptr;
    if (!is_built_in && !is_off && !is_offered_extension) {
      return;
    }

    PrefService* prefs = profile_->GetPrefs();
    prefs->SetString(kChoicePref, choice);
    // Coming back to Hudhud's password manager means using it: offering to
    // save is off by default in ungoogled-chromium, so turn it on.  An
    // extension that still controls this setting keeps it off, and the
    // Settings page says which one.
    if (is_built_in) {
      prefs->SetBoolean(password_manager::prefs::kCredentialsEnableService,
                        true);
    }
  }

  // args: [the id of an offered extension]
  // Opens the extension's own page; or, when it is not installed, its page in
  // the Chrome Web Store; or, when it is turned off, its chrome://extensions
  // page, where the user can turn it on.
  void HandleOpenPasswordManager(const base::ListValue& args) {
    if (args.size() != 1 || !args[0].is_string()) {
      return;
    }
    const ExtensionPasswordManager* manager =
        FindExtensionPasswordManager(args[0].GetString());
    if (!manager) {
      return;
    }

    auto* registry = extensions::ExtensionRegistry::Get(profile_);
    const extensions::Extension* installed =
        registry->GetInstalledExtension(manager->id);
    bool enabled = registry->enabled_extensions().Contains(manager->id);

    GURL url;
    if (!installed) {
      url = GURL(extension_urls::GetWebstoreItemDetailURLPrefix() +
                 manager->id);
    } else if (!enabled) {
      url = GURL(std::string(chrome::kChromeUIExtensionsURL) +
                 "?id=" + manager->id);
    } else {
      url = installed->url().Resolve(manager->page);
    }

    // Opened by the browser, not the page: an extension's pages are not
    // reachable from other pages (they are not "web accessible").
    web_ui()->GetWebContents()->OpenURL(
        content::OpenURLParams(url, content::Referrer(),
                               WindowOpenDisposition::NEW_FOREGROUND_TAB,
                               ui::PAGE_TRANSITION_AUTO_TOPLEVEL,
                               /*is_renderer_initiated=*/false),
        /*navigation_handle_callback=*/{});
  }

  raw_ptr<Profile> profile_;
  PrefChangeRegistrar pref_change_registrar_;
  base::ScopedObservation<extensions::ExtensionRegistry,
                          extensions::ExtensionRegistryObserver>
      registry_observation_{this};
};

}  // namespace

void AddChoiceToPage(content::WebUI* web_ui, content::WebUIDataSource* source) {
  // Chromium sets the default locale to the browser's own language, as the
  // Shields button reads it too (shields_toolbar_button.cc)
  bool is_arabic = base::i18n::GetConfiguredLocale().starts_with("ar");
  for (const PageString& string : kPageStrings) {
    source->AddString(string.id, is_arabic ? string.arabic : string.english);
  }
  web_ui->AddMessageHandler(
      std::make_unique<ChoiceHandler>(Profile::FromWebUI(web_ui)));
}

}  // namespace hudhud_password_manager
