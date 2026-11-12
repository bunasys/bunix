// Buna Browser's Shields (bunix: docs/browser.md, "Shields").

#include "chrome/browser/buna_shields/shields_tab_helper.h"

#include <string>
#include <utility>
#include <vector>

#include "base/json/json_writer.h"
#include "base/strings/utf_string_conversions.h"
#include "chrome/browser/buna_shields/shields_engine.h"
#include "chrome/browser/content_settings/host_content_settings_map_factory.h"
#include "chrome/common/chrome_isolated_world_ids.h"
#include "components/content_settings/core/browser/host_content_settings_map.h"
#include "content/public/browser/render_frame_host.h"
#include "content/public/browser/weak_document_ptr.h"
#include "content/public/browser/web_contents.h"

namespace buna_shields {

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

}  // namespace buna_shields
