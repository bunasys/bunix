// Hudhud's Shields (bunix: docs/browser.md, "Shields"): the engine,
// and the per-site switch that both of its callers (the request blocker
// and the element hider) check.

#ifndef CHROME_BROWSER_HUDHUD_SHIELDS_SHIELDS_ENGINE_H_
#define CHROME_BROWSER_HUDHUD_SHIELDS_SHIELDS_ENGINE_H_

#include <atomic>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include "base/no_destructor.h"
#include "base/values.h"
#include "url/gurl.h"

class HostContentSettingsMap;
struct HudhudShields;

namespace hudhud_shields {

// The ad and tracker blocker: Brave's adblock-rust in libhudhud_shields.so,
// and the filter lists compiled into shields.dat, both next to the browser
// (bunix: base/hudhud-shields.bst).  Loaded once, in the background, on first
// use; until then, and if loading fails, nothing is blocked.  Usable from
// any thread.
class ShieldsEngine {
 public:
  static ShieldsEngine& Get();

  // Starts loading the engine in the background, if it has not started.
  static void StartLoading();

  ShieldsEngine(const ShieldsEngine&) = delete;
  ShieldsEngine& operator=(const ShieldsEngine&) = delete;

  // Whether the lists block a request for `url` made by a document at
  // `source`.  `request_type` is adblock-rust's name for what is loaded
  // ("script", "image", "sub_frame", ...).
  bool ShouldBlock(const GURL& url,
                   const GURL& source,
                   std::string_view request_type) const;

  // What to hide on the page at a URL.
  struct PageResources {
    PageResources();
    PageResources(PageResources&&);
    ~PageResources();

    // CSS selectors of elements to hide, specific to this site
    std::vector<std::string> hide_selectors;
    // generic rules that must not apply here; opaque, only handed back to
    // GetHiddenSelectors (kept as the list it is passed as)
    base::ListValue exceptions;
    // no generic rules at all on this page
    bool generichide = false;
  };
  std::optional<PageResources> GetPageResources(const GURL& url) const;

  // CSS selectors of the generic hiding rules that apply to elements with
  // these classes and ids (lists of strings).
  std::vector<std::string> GetHiddenSelectors(
      const base::ListValue& classes,
      const base::ListValue& ids,
      const base::ListValue& exceptions) const;

 private:
  friend class base::NoDestructor<ShieldsEngine>;

  ShieldsEngine();
  ~ShieldsEngine();

  // Runs in the background: loads the library and the engine file, then
  // publishes the engine.  Started by the first StartLoading() or Get().
  void Load();

  // The library's functions (hudhud_shields.h); set before `engine_` is.
  struct Functions;
  Functions* functions_ = nullptr;
  std::atomic<HudhudShields*> engine_{nullptr};
};

// Shields are up on a site unless its user turned them down there.  They
// keep Chromium's "ads" content setting, which page info shows as each
// site's switch: Block (the default) is up, Allow is down.  `site` is the
// URL of the tab's top document.
bool AreShieldsUp(const HostContentSettingsMap& settings, const GURL& site);

}  // namespace hudhud_shields

#endif  // CHROME_BROWSER_HUDHUD_SHIELDS_SHIELDS_ENGINE_H_
