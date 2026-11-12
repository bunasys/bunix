#!/usr/bin/env python3
"""Makes Hudhud's patches (files/hudhud/patches) from a Chromium tree with
ungoogled-chromium's patches, the platform's and files/hudhud/ungoogled/
patches applied, but not these (files/hudhud/scripts/prepare-source.sh):

    make-patches.py <chromium tree> files/hudhud/patches [<patch name>...]

A patch is numbered by its place in the list below.  Made all at once, the
old numbered patches are removed first, so that a renumbered one is not left
behind to be applied twice.  With patch names, only those are made, which
needs only the files they change.

The patches are generated: edit them here, not in the .patch files.  Each
edit names the exact text it replaces, which must occur once in the file,
so a new Chromium version that moved the text fails here, loudly, instead
of being patched in the wrong place.
"""

import difflib
import os
import sys

tree, out = sys.argv[1], sys.argv[2]
only = sys.argv[3:]

# (name, file, [(old text, new text), ...])
PATCHES = [
    ("shields-network", "chrome/browser/chrome_content_browser_client.cc", [
      ('#include "chrome/browser/accessibility/caption_settings_dialog.h"\n',
       '#include "chrome/browser/accessibility/caption_settings_dialog.h"\n'
       '#include "chrome/browser/hudhud_shields/shields_url_loader_factory.h"\n'),
      ('  signin::ProxyingURLLoaderFactory::MaybeProxyRequest(\n'
       '      frame, type == URLLoaderFactoryType::kNavigation, request_initiator,\n'
       '      isolation_info, factory_builder);\n',
       '  signin::ProxyingURLLoaderFactory::MaybeProxyRequest(\n'
       '      frame, type == URLLoaderFactoryType::kNavigation, request_initiator,\n'
       '      isolation_info, factory_builder);\n'
       '\n'
       '  // Hudhud: Shields block ads and trackers\n'
       '  hudhud_shields::MaybeProxyURLLoaderFactory(browser_context, frame, type,\n'
       '                                           isolation_info, factory_builder);\n'),
    ]),
    ("shields-tab-helper", "chrome/browser/ui/tab_helpers.cc", [
      ('#include "chrome/browser/bookmarks/bookmark_model_factory.h"\n',
       '#include "chrome/browser/bookmarks/bookmark_model_factory.h"\n'
       '#include "chrome/browser/hudhud_shields/shields_tab_helper.h"\n'),
      ('  infobars::ContentInfoBarManager::CreateForWebContents(web_contents);\n',
       '  infobars::ContentInfoBarManager::CreateForWebContents(web_contents);\n'
       '  // Hudhud: Shields hide what blocked ads leave behind\n'
       '  hudhud_shields::ShieldsTabHelper::CreateForWebContents(web_contents);\n'),
    ]),
    ("shields-build", "chrome/browser/BUILD.gn", [
      ('  deps = [\n'
       '    ":active_use_util",\n',
       '  deps = [\n'
       '    # Hudhud: Shields (chrome_content_browser_client.cc)\n'
       '    "//chrome/browser/hudhud_shields",\n'
       '    ":active_use_util",\n'),
    ]),
    ("shields-page-info-switch", "components/page_info/page_info.cc", [
      ('  // Note |ContentSettingsType::ADS| will show up regardless of its default\n'
       '  // value when it has been activated on the current origin.\n'
       '  if (info.type == ContentSettingsType::ADS) {\n'
       '    if (!base::FeatureList::IsEnabled(\n'
       '            subresource_filter::kSafeBrowsingSubresourceFilter)) {\n'
       '      return false;\n'
       '    }\n'
       '\n'
       '    return delegate_->IsSubresourceFilterActivated(site_url_);\n'
       '  }\n',
       '  // Hudhud: the ads setting is the Shields switch of every site\n'
       '  if (info.type == ContentSettingsType::ADS) {\n'
       '    return true;\n'
       '  }\n'),
    ]),
    ("policy-path", "components/policy/core/common/policy_paths.cc", [
      ('const char kPolicyPath[] = "/etc/chromium/policies";\n',
       '// Hudhud: its defaults are part of the signed /usr\n'
       'const char kPolicyPath[] = "/usr/share/hudhud/policies";\n'),
    ]),
    ("profile-directory", "chrome/common/chrome_paths_linux.cc", [
      ('  std::string data_dir_basename = "chromium";\n',
       '  std::string data_dir_basename = "hudhud";\n'),
    ]),
    ("no-web-store-tile", "chrome/browser/history/top_sites_factory.cc", [
      ('  PrefService* pref_service = profile->GetPrefs();\n'
       '  bool hide_web_store_icon =\n'
       '      pref_service->GetBoolean(policy::policy_prefs::kHideWebStoreIcon);\n',
       '  // Hudhud: the start page has no Web Store tile, whatever the policy says\n'
       '  bool hide_web_store_icon = true;\n'),
    ]),
    ("shields-tab-helper-build", "chrome/browser/ui/BUILD.gn", [
      ('  public_deps = [ ":tab_helpers" ]\n'
       '\n'
       '  deps = [\n'
       '    ":recently_audible_helper",\n',
       '  public_deps = [ ":tab_helpers" ]\n'
       '\n'
       '  deps = [\n'
       '    ":recently_audible_helper",\n'
       '    # Hudhud: Shields (tab_helpers.cc)\n'
       '    "//chrome/browser/hudhud_shields",\n'),
    ]),
    ("shields-button", "chrome/browser/ui/views/toolbar/toolbar_view.cc", [
      ('#include "chrome/browser/ui/views/toolbar/split_tabs_button.h"\n',
       '#include "chrome/browser/ui/views/toolbar/split_tabs_button.h"\n'
       '#include "chrome/browser/ui/views/hudhud_shields/shields_toolbar_button.h"\n'),
      ('  if (location_bar_view) {\n'
       '    location_bar_view_ = AddChildView(std::move(location_bar_view));\n'
       '    location_bar_ = location_bar_view_;\n'
       '  } else {\n'
       '    location_bar_ = toolbar_webview_->GetLocationBar();\n'
       '  }\n',
       '  if (location_bar_view) {\n'
       '    location_bar_view_ = AddChildView(std::move(location_bar_view));\n'
       '    location_bar_ = location_bar_view_;\n'
       '  } else {\n'
       '    location_bar_ = toolbar_webview_->GetLocationBar();\n'
       '  }\n'
       '\n'
       '  // Hudhud: the Shields button, right of the address bar\n'
       '  AddChildView(\n'
       '      std::make_unique<hudhud_shields::ShieldsToolbarButton>(browser_));\n'),
    ]),
    ("shields-button-build", "chrome/browser/ui/views/toolbar/BUILD.gn", [
      ('    "//chrome/browser/ui/views/global_media_controls",\n'
       '    "//chrome/browser/ui/views/interaction",\n',
       '    "//chrome/browser/ui/views/global_media_controls",\n'
       '    # Hudhud: the Shields button (toolbar_view.cc)\n'
       '    "//chrome/browser/ui/views/hudhud_shields",\n'
       '    "//chrome/browser/ui/views/interaction",\n'),
    ]),
    # --- The choice: Hudhud's own password manager obeys it ---------------
    ("password-manager-choice-client",
     "chrome/browser/password_manager/chrome_password_manager_client.cc", [
      ('#include "chrome/browser/history/history_tab_helper.h"\n',
       '#include "chrome/browser/history/history_tab_helper.h"\n'
       '#include "chrome/browser/hudhud_password_manager/password_manager_choice.h"\n'),
      ('bool ChromePasswordManagerClient::IsFillingEnabled(\n'
       '    const url::Origin& origin,\n'
       '    base::optional_ref<const GURL> url) const {\n',
       'bool ChromePasswordManagerClient::IsFillingEnabled(\n'
       '    const url::Origin& origin,\n'
       '    base::optional_ref<const GURL> url) const {\n'
       '  // Hudhud: with another password manager chosen, or none, this one\n'
       '  // neither fills nor offers to save (saving asks this first)\n'
       '  if (!hudhud_password_manager::IsBuiltInPasswordManagerChosen(\n'
       '          GetPrefs())) {\n'
       '    return false;\n'
       '  }\n'
       '\n'),
    ]),
    ("password-manager-choice-client-build",
     "chrome/browser/password_manager/BUILD.gn", [
      ('    "//chrome/browser/history",\n'
       '    "//chrome/browser/optimization_guide",\n',
       '    "//chrome/browser/history",\n'
       '    "//chrome/browser/hudhud_password_manager:choice",\n'
       '    "//chrome/browser/optimization_guide",\n'),
    ]),

    # --- The choice's pref ---------------------------------------------------
    ("password-manager-choice-pref", "chrome/browser/prefs/browser_prefs.cc", [
      ('#include "chrome/browser/hid/hid_policy_allowed_devices.h"\n',
       '#include "chrome/browser/hid/hid_policy_allowed_devices.h"\n'
       '#include "chrome/browser/hudhud_password_manager/password_manager_choice.h"\n'),
      ('  password_manager::PasswordManager::RegisterProfilePrefs(registry);\n',
       '  password_manager::PasswordManager::RegisterProfilePrefs(registry);\n'
       '  hudhud_password_manager::RegisterProfilePrefs(registry);\n'),
    ]),
    ("password-manager-choice-pref-build", "chrome/browser/prefs/BUILD.gn", [
      ('    "//chrome/browser:intranet_redirect_detector",\n',
       '    "//chrome/browser:intranet_redirect_detector",\n'
       '    "//chrome/browser/hudhud_password_manager:choice",\n'),
    ]),

    # --- chrome://password-manager: strings and messages --------------------
    ("password-manager-choice-ui",
     "chrome/browser/ui/webui/password_manager/password_manager_ui.cc", [
      ('#include "chrome/browser/extensions/api/passwords_private/passwords_private_delegate_factory.h"\n',
       '#include "chrome/browser/extensions/api/passwords_private/passwords_private_delegate_factory.h"\n'
       '#include "chrome/browser/hudhud_password_manager/password_manager_choice_page.h"\n'),
      ('  policy_indicator::AddLocalizedStrings(source);\n',
       '  policy_indicator::AddLocalizedStrings(source);\n'
       '  // Hudhud: the user chooses the password manager: this one, an\n'
       '  // extension, or none\n'
       '  hudhud_password_manager::AddChoiceToPage(web_ui, source);\n'),
    ]),
    ("password-manager-choice-ui-build",
     "chrome/browser/ui/webui/password_manager/BUILD.gn", [
      ('    "//chrome/browser/ui/webui:extension_control_handler",\n',
       '    "//chrome/browser/ui/webui:extension_control_handler",\n'
       '    "//chrome/browser/hudhud_password_manager:page",\n'),
    ]),

    # --- chrome://password-manager: the <hudhud-password-manager-choice> ---
    ("password-manager-choice-resources-build",
     "chrome/browser/resources/password_manager/BUILD.gn", [
      ('    "full_data_reset.ts",\n',
       '    "full_data_reset.ts",\n'
       '    "hudhud_password_manager_choice.ts",\n'),
    ]),
    ("password-manager-choice-app-script",
     "chrome/browser/resources/password_manager/password_manager_app.ts", [
      ("import './settings_section.js';\n",
       "import './hudhud_password_manager_choice.js';\n"
       "import './settings_section.js';\n"),
    ]),
    ("password-manager-choice-app",
     "chrome/browser/resources/password_manager/password_manager_app.html", [
      ('  password-manager-side-bar {\n'
       '    min-width: var(--side-bar-width);\n'
       '  }\n'
       '</style>\n',
       '  password-manager-side-bar {\n'
       '    min-width: var(--side-bar-width);\n'
       '  }\n'
       '\n'
       '  /* Hudhud: with another password manager chosen, or none, the\n'
       '   * choice is the whole page. */\n'
       '  hudhud-password-manager-choice[replaces-built-in] ~ #toolbar,\n'
       '  hudhud-password-manager-choice[replaces-built-in] ~ #container {\n'
       '    display: none;\n'
       '  }\n'
       '</style>\n'),
      ('<settings-prefs id="prefs" prefs="{{prefs_}}"></settings-prefs>\n',
       '<settings-prefs id="prefs" prefs="{{prefs_}}"></settings-prefs>\n'
       '<hudhud-password-manager-choice full-page>\n'
       '</hudhud-password-manager-choice>\n'),
    ]),
    ("password-manager-choice-settings-script",
     "chrome/browser/resources/password_manager/settings_section.ts", [
      ("import './full_data_reset.js';\n",
       "import './full_data_reset.js';\n"
       "import './hudhud_password_manager_choice.js';\n"),
    ]),
    ("password-manager-choice-settings",
     "chrome/browser/resources/password_manager/settings_section.html", [
      ('<h2 class="page-title">$i18n{settings}</h2>\n',
       '<h2 class="page-title">$i18n{settings}</h2>\n'
       '<hudhud-password-manager-choice></hudhud-password-manager-choice>\n'),
    ]),

    # --- no "Related Google services" on chrome://settings/autofill -------
    # Its rows are a second way to the password manager (the card above has
    # it) and links to Google Wallet and the Google Account, whose addresses
    # ungoogled-chromium's domain substitution has already broken.
    ("no-related-google-services",
     "chrome/browser/resources/settings/autofill_page/autofill_page.html.ts", [
      # The removed rows had the id that macOS's passkeys page returns focus
      # to (autofill_page.ts, getAssociatedControlFor): the password
      # manager's card takes it.
      ('  <category-reference-card card-title="$i18n{localPasswordManager}"\n'
       '      is-external\n',
       '  <category-reference-card id="passwordManagerButton"\n'
       '      card-title="$i18n{localPasswordManager}"\n'
       '      is-external\n'),
      ('<settings-section page-title="$i18n{yourSavedInfoRelatedServicesTitle}">\n'
       '  <div route-path="default">\n'
       '    <cr-link-row id="passwordManagerButton" label="$i18n{localPasswordManager}"\n'
       '        @click="${this.onPasswordManagerRelatedServiceClick_}"\n'
       '        start-icon="cr20:password-manager" external>\n'
       '    </cr-link-row>\n'
       '    <cr-link-row id="googleWalletButton" label="$i18n{googleWalletTitle}"\n'
       '        @click="${this.onGoogleWalletRelatedServiceClick_}"\n'
       '        start-icon="settings20:wallet" external>\n'
       '    </cr-link-row>\n'
       '    <cr-link-row id="googleAccountButton" label="$i18n{googleAccount}"\n'
       '        @click="${this.onGoogleAccountRelatedServiceClick_}"\n'
       '        start-icon="settings20:google" external>\n'
       '    </cr-link-row>\n'
       '  </div>\n'
       '</settings-section>\n',
       ''),
    ]),
    ("native-messaging-from-chrome",
     "chrome/browser/extensions/api/messaging/launch_context_posix.cc", [
      ('#include <utility>\n',
       '#include <utility>\n'
       '#include <vector>\n'),
      ('#include "base/command_line.h"\n',
       '#include "base/base_paths.h"\n'
       '#include "base/command_line.h"\n'),
      ('}  // namespace\n'
       '\n'
       '// static\n'
       'base::FilePath LaunchContext::FindManifest(',
       '// Hudhud: password managers and other desktop apps register their\n'
       '// browser helpers for Google Chrome, not for Hudhud, so Chrome\'s folders\n'
       '// are looked in last.  A helper\'s manifest still names the extensions\n'
       '// allowed to use it (allowed_origins).\n'
       'base::FilePath FindManifestForChrome(const std::string& host_name,\n'
       '                                     bool allow_user_level_hosts) {\n'
       '  std::vector<base::FilePath> dirs;\n'
       '#if BUILDFLAG(IS_MAC)\n'
       '  base::FilePath app_support;\n'
       '  if (allow_user_level_hosts &&\n'
       '      base::PathService::Get(base::DIR_APP_DATA, &app_support)) {\n'
       '    dirs.push_back(app_support.Append("Google/Chrome/NativeMessagingHosts"));\n'
       '  }\n'
       '  dirs.push_back(base::FilePath("/Library/Google/Chrome/NativeMessagingHosts"));\n'
       '#else\n'
       '  base::FilePath home;\n'
       '  if (allow_user_level_hosts &&\n'
       '      base::PathService::Get(base::DIR_HOME, &home)) {\n'
       '    dirs.push_back(home.Append(".config/google-chrome/NativeMessagingHosts"));\n'
       '  }\n'
       '  dirs.push_back(base::FilePath("/etc/opt/chrome/native-messaging-hosts"));\n'
       '#endif\n'
       '  for (const base::FilePath& dir : dirs) {\n'
       '    base::FilePath path = dir.Append(host_name + ".json");\n'
       '    if (base::PathExists(path)) {\n'
       '      return path;\n'
       '    }\n'
       '  }\n'
       '  return base::FilePath();\n'
       '}\n'
       '\n'
       '}  // namespace\n'
       '\n'
       '// static\n'
       'base::FilePath LaunchContext::FindManifest('),
      ('  if (result.empty()) {\n'
       '    result = FindManifestInDir(chrome::DIR_NATIVE_MESSAGING, host_name);\n'
       '  }\n',
       '  if (result.empty()) {\n'
       '    result = FindManifestInDir(chrome::DIR_NATIVE_MESSAGING, host_name);\n'
       '  }\n'
       '  if (result.empty()) {\n'
       '    result = FindManifestForChrome(host_name, allow_user_level_hosts);\n'
       '  }\n'),
    ]),
    ("safe-storage-name", "components/os_crypt/common/keychain_password_mac.mm", [
      ('#else\n'
       'const char kDefaultServiceName[] = "Chromium Safe Storage";\n'
       'const char kDefaultAccountName[] = "Chromium";\n'
       '#endif\n',
       '#else\n'
       '// Hudhud: its own keychain item, not one shared with Chromium\n'
       'const char kDefaultServiceName[] = "Hudhud Safe Storage";\n'
       'const char kDefaultAccountName[] = "Hudhud";\n'
       '#endif\n'),
    ]),
    ("safe-storage-name-linux",
     "components/os_crypt/async/browser/freedesktop_secret_key_provider.h", [
      ('  static constexpr char kKWalletFolder[] = "Chromium Keys";\n'
       '  static constexpr char kKeyName[] = "Chromium Safe Storage";\n'
       '  static constexpr char kAppName[] = "chromium";\n',
       '  // Hudhud: its own secret, not one shared with Chromium\n'
       '  static constexpr char kKWalletFolder[] = "Hudhud Keys";\n'
       '  static constexpr char kKeyName[] = "Hudhud Safe Storage";\n'
       '  static constexpr char kAppName[] = "hudhud";\n'),
    ]),
]

os.makedirs(out, exist_ok=True)
if not only:
    for old_patch in os.listdir(out):
        if old_patch[:2].isdigit() and old_patch.endswith(".patch"):
            os.remove(os.path.join(out, old_patch))
for number, (name, path, edits) in enumerate(PATCHES, 1):
    if only and name not in only:
        continue
    old_text = open(os.path.join(tree, path), encoding="utf-8").read()
    new_text = old_text
    for old, new in edits:
        count = new_text.count(old)
        if count != 1:
            sys.exit(f"{name}: {path}: the text to replace occurs {count} times:\n{old}")
        new_text = new_text.replace(old, new)

    diff = difflib.unified_diff(old_text.splitlines(keepends=True),
                                new_text.splitlines(keepends=True),
                                f"a/{path}", f"b/{path}")
    patch = f"{out}/{number:02d}-{name}.patch"
    with open(patch, "w", encoding="utf-8") as output:
        # patch(1) skips text before the diff
        output.write("Generated by files/hudhud/make-patches.py: edit that, not this.\n\n")
        output.writelines(diff)
    print(patch)
