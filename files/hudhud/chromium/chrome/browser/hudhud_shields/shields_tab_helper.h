// Buna Browser's Shields (bunix: docs/browser.md, "Shields").

#ifndef CHROME_BROWSER_BUNA_SHIELDS_SHIELDS_TAB_HELPER_H_
#define CHROME_BROWSER_BUNA_SHIELDS_SHIELDS_TAB_HELPER_H_

#include "content/public/browser/web_contents_observer.h"
#include "content/public/browser/web_contents_user_data.h"

namespace buna_shields {

// Hides what the filter lists' element-hiding rules name, in every frame of
// a tab, once its document is parsed and again once it has loaded (to catch
// what scripts added): the site's own rules, and the generic rules that
// apply to the classes and ids on the page.  The blocked requests leave
// empty boxes behind; this removes them.
class ShieldsTabHelper : public content::WebContentsObserver,
                         public content::WebContentsUserData<ShieldsTabHelper> {
 public:
  ShieldsTabHelper(const ShieldsTabHelper&) = delete;
  ShieldsTabHelper& operator=(const ShieldsTabHelper&) = delete;
  ~ShieldsTabHelper() override;

  // content::WebContentsObserver:
  void DOMContentLoaded(content::RenderFrameHost* frame) override;
  void DidFinishLoad(content::RenderFrameHost* frame,
                     const GURL& validated_url) override;

 private:
  friend class content::WebContentsUserData<ShieldsTabHelper>;
  explicit ShieldsTabHelper(content::WebContents* web_contents);

  void HideElements(content::RenderFrameHost* frame);

  WEB_CONTENTS_USER_DATA_KEY_DECL();
};

}  // namespace buna_shields

#endif  // CHROME_BROWSER_BUNA_SHIELDS_SHIELDS_TAB_HELPER_H_
