// Hudhud's Shields (bunix: docs/browser.md, "Shields").

#ifndef CHROME_BROWSER_UI_VIEWS_HUDHUD_SHIELDS_SHIELDS_TOOLBAR_BUTTON_H_
#define CHROME_BROWSER_UI_VIEWS_HUDHUD_SHIELDS_SHIELDS_TOOLBAR_BUTTON_H_

#include "base/callback_list.h"
#include "base/memory/raw_ptr.h"
#include "base/memory/weak_ptr.h"
#include "chrome/browser/ui/views/toolbar/toolbar_button.h"
#include "ui/base/metadata/metadata_header_macros.h"

class BrowserWindowInterface;

namespace views {
class Widget;
}

namespace hudhud_shields {

class ShieldsTabHelper;

// The Shields button, beside the address bar: the hoopoe, with how many ads
// and trackers Shields blocked on the page the window shows, greyed on a site
// the user turned Shields down for.  Pressed, it opens the Shields panel: the
// site, what was blocked there, and the site's switch, which reloads the
// page.  Follows the window's active tab by itself: ToolbarView only adds it.
class ShieldsToolbarButton : public ToolbarButton {
  METADATA_HEADER(ShieldsToolbarButton, ToolbarButton)

 public:
  explicit ShieldsToolbarButton(BrowserWindowInterface* browser);
  ShieldsToolbarButton(const ShieldsToolbarButton&) = delete;
  ShieldsToolbarButton& operator=(const ShieldsToolbarButton&) = delete;
  ~ShieldsToolbarButton() override;

  // ToolbarButton:
  void UpdateIcon() override;

 private:
  void OnActiveTabChanged(BrowserWindowInterface* browser);

  // Shows the active tab's count and switch.
  void Update();

  void OpenOrClosePanel();
  void FlipShields();

  // Null very early and very late in a window's life.
  ShieldsTabHelper* GetActiveTabHelper();

  raw_ptr<BrowserWindowInterface> browser_;
  base::CallbackListSubscription active_tab_subscription_;
  base::CallbackListSubscription tab_helper_subscription_;
  // The open panel; the widget owns itself and closes on its own (when it
  // loses focus), so only watched
  base::WeakPtr<views::Widget> panel_;
  base::WeakPtrFactory<ShieldsToolbarButton> weak_factory_{this};
};

}  // namespace hudhud_shields

#endif  // CHROME_BROWSER_UI_VIEWS_HUDHUD_SHIELDS_SHIELDS_TOOLBAR_BUTTON_H_
