// Hudhud's Shields (bunix: docs/browser.md, "Shields").

#include "chrome/browser/hudhud_shields/shields_tab_helper.h"

#include <algorithm>
#include <functional>
#include <map>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "base/json/json_writer.h"
#include "base/strings/utf_string_conversions.h"
#include "chrome/browser/hudhud_shields/shields_engine.h"
#include "chrome/browser/content_settings/host_content_settings_map_factory.h"
#include "chrome/common/chrome_isolated_world_ids.h"
#include "components/content_settings/core/browser/host_content_settings_map.h"
#include "components/content_settings/core/common/content_settings.h"
#include "components/content_settings/core/common/content_settings_types.h"
#include "content/public/browser/navigation_controller.h"
#include "content/public/browser/page.h"
#include "content/public/browser/page_user_data.h"
#include "content/public/browser/reload_type.h"
#include "content/public/browser/render_frame_host.h"
#include "content/public/browser/web_contents.h"

namespace hudhud_shields {

namespace {

// Runs in an isolated world (the page cannot see or change it): every class
// and id on the page, at most 5000 of them -- enough for any page, and a
// bound on what a hostile one can make the engine match.
constexpr char16_t kCollectClassesAndIds[] = uR"(
(() => {
  const classes = new Set();
  const ids = new Set();
  for (const element of document.querySelectorAll('[class], [id]')) {
    for (const name of element.classList) classes.add(name);
    if (element.id) ids.add(element.id);
    if (classes.size + ids.size > 5000) break;
  }
  return {classes: [...classes], ids: [...ids]};
})()
)";

// Adds a style sheet that hides the selected elements.  One rule per
// selector: a selector this browser does not understand then voids only
// its own rule.
void InsertHidingStyle(content::RenderFrameHost* frame,
                       const std::vector<std::string>& selectors) {
  if (selectors.empty()) {
    return;
  }
  std::string css;
  for (const std::string& selector : selectors) {
    css += selector + " { display: none !important; }\n";
  }
  // JSON-encoded: a JSON string is a safe JavaScript string literal
  std::string css_literal = base::WriteJson(base::Value(css)).value_or("\"\"");
  std::string script =
      "(() => { const style = document.createElement('style');"
      " style.textContent = " +
      css_literal +
      "; (document.head || document.documentElement).appendChild(style);"
      " })()";
  frame->ExecuteJavaScriptInIsolatedWorld(base::UTF8ToUTF16(script),
                                          base::DoNothing(),
                                          ISOLATED_WORLD_ID_CHROME_INTERNAL);
}

void HideGenericMatches(content::WeakDocumentPtr document,
                        base::ListValue exceptions,
                        base::Value classes_and_ids) {
  content::RenderFrameHost* frame = document.AsRenderFrameHostIfValid();
  if (!frame || !classes_and_ids.is_dict()) {
    return;
  }
  const base::DictValue& dict = classes_and_ids.GetDict();
  const base::ListValue* classes = dict.FindList("classes");
  const base::ListValue* ids = dict.FindList("ids");
  if (!classes || !ids) {
    return;
  }
  InsertHidingStyle(frame, ShieldsEngine::Get().GetHiddenSelectors(
                               *classes, *ids, exceptions));
}

// What Shields blocked on one page.  Kept with the page rather than the tab,
// so that a new page starts from nothing, and a page shown again from the
// back-forward cache, or a prerendered one once shown, has its own count.
class BlockedOnPage : public content::PageUserData<BlockedOnPage> {
 public:
  ~BlockedOnPage() override = default;

  void Add(const GURL& url) {
    ++count_;
    // A page can make up any number of hosts; past this many, its blocks
    // still count but their hosts are not kept.
    constexpr size_t kMaxHosts = 500;
    bool is_new_host = !blocks_per_host_.contains(url.host());
    bool is_full = blocks_per_host_.size() >= kMaxHosts;
    if (is_new_host && is_full) {
      return;
    }
    ++blocks_per_host_[std::string(url.host())];
  }

  int count() const { return count_; }

  const std::map<std::string, int, std::less<>>& blocks_per_host() const {
    return blocks_per_host_;
  }

 private:
  friend class content::PageUserData<BlockedOnPage>;
  explicit BlockedOnPage(content::Page& page)
      : content::PageUserData<BlockedOnPage>(page) {}

  int count_ = 0;
  std::map<std::string, int, std::less<>> blocks_per_host_;

  PAGE_USER_DATA_KEY_DECL();
};

PAGE_USER_DATA_KEY_IMPL(BlockedOnPage);

}  // namespace

ShieldsTabHelper::ShieldsTabHelper(content::WebContents* web_contents)
    : content::WebContentsObserver(web_contents),
      content::WebContentsUserData<ShieldsTabHelper>(*web_contents) {}

ShieldsTabHelper::~ShieldsTabHelper() = default;

void ShieldsTabHelper::DOMContentLoaded(content::RenderFrameHost* frame) {
  HideElements(frame);
}

void ShieldsTabHelper::DidFinishLoad(content::RenderFrameHost* frame,
                                     const GURL& validated_url) {
  HideElements(frame);
}

// static
void ShieldsTabHelper::RecordBlocked(const TabPage& page, const GURL& url) {
  content::RenderFrameHost* main_document =
      page.main_document.AsRenderFrameHostIfValid();
  if (!main_document) {
    // the first page of a new tab (TabPage); a frame already gone counts
    // for nothing
    main_document = content::RenderFrameHost::FromID(page.main_frame);
  }
  if (!main_document) {
    return;
  }
  BlockedOnPage* blocked =
      BlockedOnPage::GetOrCreateForPage(main_document->GetPage());
  // Chromium's PageUserData can come back missing even when just made
  // (crbug.com/40847334)
  if (!blocked) {
    return;
  }
  blocked->Add(url);

  bool is_page_shown = main_document->GetPage().IsPrimary();
  if (!is_page_shown) {
    return;
  }
  ShieldsTabHelper* helper = FromWebContents(
      content::WebContents::FromRenderFrameHost(main_document));
  if (helper) {
    helper->changed_callbacks_.Notify();
  }
}

int ShieldsTabHelper::GetBlockedCount() const {
  const BlockedOnPage* blocked =
      BlockedOnPage::GetForPage(web_contents()->GetPrimaryPage());
  return blocked ? blocked->count() : 0;
}

std::vector<std::string> ShieldsTabHelper::GetMostBlockedHosts(
    size_t limit) const {
  const BlockedOnPage* blocked =
      BlockedOnPage::GetForPage(web_contents()->GetPrimaryPage());
  if (!blocked) {
    return {};
  }
  std::vector<std::pair<std::string, int>> hosts(
      blocked->blocks_per_host().begin(), blocked->blocks_per_host().end());
  std::stable_sort(hosts.begin(), hosts.end(),
                   [](const std::pair<std::string, int>& a,
                      const std::pair<std::string, int>& b) {
                     return a.second > b.second;
                   });
  std::vector<std::string> most_blocked;
  for (size_t i = 0; i < hosts.size() && i < limit; ++i) {
    most_blocked.push_back(hosts[i].first);
  }
  return most_blocked;
}

GURL ShieldsTabHelper::GetPageURL() const {
  return web_contents()->GetPrimaryMainFrame()->GetLastCommittedURL();
}

bool ShieldsTabHelper::AreShieldsUpOnSite() const {
  HostContentSettingsMap* settings =
      HostContentSettingsMapFactory::GetForProfile(
          web_contents()->GetBrowserContext());
  return AreShieldsUp(*settings, GetPageURL());
}

void ShieldsTabHelper::SetShieldsUpOnSite(bool up) {
  HostContentSettingsMap* settings =
      HostContentSettingsMapFactory::GetForProfile(
          web_contents()->GetBrowserContext());
  // Up is the default (the ads setting's Block): the site's exception is
  // removed rather than a Block written, so that site settings list only
  // the sites Shields are down on.  Default scope: the site's origin, as
  // page info writes it, so that the two switches always agree.
  ContentSetting setting = up ? CONTENT_SETTING_DEFAULT : CONTENT_SETTING_ALLOW;
  settings->SetContentSettingDefaultScope(GetPageURL(), GURL(),
                                          ContentSettingsType::ADS, setting);
  web_contents()->GetController().Reload(content::ReloadType::NORMAL,
                                         /*check_for_repost=*/true);
}

base::CallbackListSubscription ShieldsTabHelper::RegisterChanged(
    base::RepeatingClosure callback) {
  return changed_callbacks_.Add(std::move(callback));
}

void ShieldsTabHelper::PrimaryPageChanged(content::Page& page) {
  changed_callbacks_.Notify();
}

void ShieldsTabHelper::HideElements(content::RenderFrameHost* frame) {
  const GURL& url = frame->GetLastCommittedURL();
  if (!url.SchemeIsHTTPOrHTTPS()) {
    return;
  }
  const GURL& site = frame->GetOutermostMainFrame()->GetLastCommittedURL();
  HostContentSettingsMap* settings =
      HostContentSettingsMapFactory::GetForProfile(
          web_contents()->GetBrowserContext());
  if (!AreShieldsUp(*settings, site)) {
    return;
  }

  std::optional<ShieldsEngine::PageResources> resources =
      ShieldsEngine::Get().GetPageResources(url);
  if (!resources) {
    return;
  }
  InsertHidingStyle(frame, resources->hide_selectors);
  if (resources->generichide) {
    return;
  }
  frame->ExecuteJavaScriptInIsolatedWorld(
      kCollectClassesAndIds,
      base::BindOnce(&HideGenericMatches, frame->GetWeakDocumentPtr(),
                     std::move(resources->exceptions)),
      ISOLATED_WORLD_ID_CHROME_INTERNAL);
}

WEB_CONTENTS_USER_DATA_KEY_IMPL(ShieldsTabHelper);

}  // namespace hudhud_shields
