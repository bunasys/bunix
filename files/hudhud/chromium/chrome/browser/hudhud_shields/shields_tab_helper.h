// Hudhud's Shields (bunix: docs/browser.md, "Shields").

#ifndef CHROME_BROWSER_HUDHUD_SHIELDS_SHIELDS_TAB_HELPER_H_
#define CHROME_BROWSER_HUDHUD_SHIELDS_SHIELDS_TAB_HELPER_H_

#include <string>
#include <vector>

#include "base/callback_list.h"
#include "content/public/browser/global_routing_id.h"
#include "content/public/browser/weak_document_ptr.h"
#include "content/public/browser/web_contents_observer.h"
#include "content/public/browser/web_contents_user_data.h"
#include "url/gurl.h"

namespace hudhud_shields {

// Shields in one tab:
// - Hides what the filter lists' element-hiding rules name, in every frame,
//   once its document is parsed and again once it has loaded (to catch what
//   scripts added): the site's own rules, and the generic rules that apply to
//   the classes and ids on the page.  The blocked requests leave empty boxes
//   behind; this removes them.
// - Keeps what was blocked on the tab's page, and holds the site's switch,
//   for the Shields button (chrome/browser/ui/views/hudhud_shields).
class ShieldsTabHelper : public content::WebContentsObserver,
                         public content::WebContentsUserData<ShieldsTabHelper> {
 public:
  ShieldsTabHelper(const ShieldsTabHelper&) = delete;
  ShieldsTabHelper& operator=(const ShieldsTabHelper&) = delete;
  ~ShieldsTabHelper() override;

  // The tab's page a request is made for: its main document, and the main
  // frame that shows it.  A new tab's first page reuses the frame host of
  // the tab's initial empty document, whose document (and the weak pointer
  // to it) is replaced when the page commits; the frame then shows the page.
  struct TabPage {
    content::WeakDocumentPtr main_document;
    content::GlobalRenderFrameHostId main_frame;
  };

  // Counts a request blocked for `page`; nothing if that page is gone.
  // Called by the request blocker (shields_url_loader_factory) for every
  // request it fails.
  static void RecordBlocked(const TabPage& page, const GURL& url);

  // How many requests were blocked on the page the tab shows.
  int GetBlockedCount() const;

  // The hosts blocked most often on the page the tab shows, at most
  // `limit` of them, the most blocked first.
  std::vector<std::string> GetMostBlockedHosts(size_t limit) const;

  // The URL of the page the tab shows: its site is what the switch is for.
  GURL GetPageURL() const;

  bool AreShieldsUpOnSite() const;

  // Flips the site's switch (page info shows the same one) and reloads the
  // page, which only then loads with or without Shields.
  void SetShieldsUpOnSite(bool up);

  // Runs `callback` whenever what the Shields button shows may have changed:
  // something blocked on the page the tab shows, or another page shown.
  base::CallbackListSubscription RegisterChanged(
      base::RepeatingClosure callback);

  // content::WebContentsObserver:
  void DOMContentLoaded(content::RenderFrameHost* frame) override;
  void DidFinishLoad(content::RenderFrameHost* frame,
                     const GURL& validated_url) override;
  void PrimaryPageChanged(content::Page& page) override;

 private:
  friend class content::WebContentsUserData<ShieldsTabHelper>;
  explicit ShieldsTabHelper(content::WebContents* web_contents);

  void HideElements(content::RenderFrameHost* frame);

  base::RepeatingClosureList changed_callbacks_;

  WEB_CONTENTS_USER_DATA_KEY_DECL();
};

}  // namespace hudhud_shields

#endif  // CHROME_BROWSER_HUDHUD_SHIELDS_SHIELDS_TAB_HELPER_H_
