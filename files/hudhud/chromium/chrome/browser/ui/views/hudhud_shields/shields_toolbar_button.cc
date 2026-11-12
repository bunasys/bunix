// Hudhud's Shields (bunix: docs/browser.md, "Shields").

#include "chrome/browser/ui/views/hudhud_shields/shields_toolbar_button.h"

#include <algorithm>
#include <memory>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "base/functional/bind.h"
#include "base/i18n/message_formatter.h"
#include "base/i18n/number_formatting.h"
#include "base/i18n/rtl.h"
#include "cc/paint/paint_flags.h"
#include "chrome/browser/hudhud_shields/shields_tab_helper.h"
#include "chrome/browser/ui/browser_window/public/browser_window_interface.h"
#include "chrome/browser/ui/views/hudhud_shields/hoopoe_icon.h"
#include "components/tabs/public/tab_interface.h"
#include "components/url_formatter/url_formatter.h"
#include "third_party/skia/include/core/SkBlendMode.h"
#include "third_party/skia/include/core/SkColor.h"
#include "ui/base/metadata/metadata_impl_macros.h"
#include "ui/base/models/dialog_model.h"
#include "ui/base/models/image_model.h"
#include "ui/gfx/canvas.h"
#include "ui/gfx/font_list.h"
#include "ui/gfx/geometry/insets.h"
#include "ui/gfx/geometry/rect.h"
#include "ui/gfx/geometry/size.h"
#include "ui/gfx/image/canvas_image_source.h"
#include "ui/gfx/image/image_skia.h"
#include "ui/gfx/paint_vector_icon.h"
#include "ui/views/accessibility/view_accessibility.h"
#include "ui/views/bubble/bubble_border.h"
#include "ui/views/bubble/bubble_dialog_delegate_view.h"
#include "ui/views/bubble/bubble_dialog_model_host.h"
#include "ui/views/controls/button/toggle_button.h"
#include "ui/views/controls/label.h"
#include "ui/views/layout/box_layout.h"
#include "ui/views/style/typography.h"
#include "ui/views/style/typography_provider.h"
#include "ui/views/widget/widget.h"

namespace hudhud_shields {

namespace {

// The words the button and the panel use.  Hudhud ships them in English and
// Arabic only, kept here rather than in Chromium's string resources (whose
// translations are keyed by hashes of the English text) so that both
// languages read side by side.  The counts are ICU plural messages: Arabic
// has six plural forms.
struct Strings {
  // the button's name and tooltip
  const char16_t* shields;
  // the panel's line under the site; {0} is the number blocked
  const char16_t* blocked_count;
  // the panel's line under the site when the switch is off
  const char16_t* shields_down;
  // the heading over the hosts blocked most
  const char16_t* most_blocked;
  // the switch
  const char16_t* switch_label;
};

constexpr Strings kEnglish = {
    .shields = u"Hudhud Shields",
    .blocked_count =
        u"{0, plural,"
        u" =0 {Nothing blocked on this page}"
        u" =1 {1 ad or tracker blocked on this page}"
        u" other {# ads and trackers blocked on this page}}",
    .shields_down = u"Shields are down on this site: nothing is blocked",
    .most_blocked = u"Blocked the most",
    .switch_label = u"Shields up for this site",
};

constexpr Strings kArabic = {
    .shields = u"دروع هدهد",
    .blocked_count =
        u"{0, plural,"
        u" =0 {لم يُحجب شيء في هذه الصفحة}"
        u" one {حُجب إعلان أو متتبّع واحد في هذه الصفحة}"
        u" two {حُجب إعلانان أو متتبّعان في هذه الصفحة}"
        u" few {حُجبت # إعلانات ومتتبّعات في هذه الصفحة}"
        u" many {حُجب # إعلانًا ومتتبّعًا في هذه الصفحة}"
        u" other {حُجب # إعلان ومتتبّع في هذه الصفحة}}",
    .shields_down = u"الدروع معطّلة في هذا الموقع: لا يُحجب شيء",
    .most_blocked = u"الأكثر حجبًا",
    .switch_label = u"تفعيل الدروع في هذا الموقع",
};

const Strings& GetStrings() {
  // Chromium configures the process's locale as the browser's UI language
  // ("ar", "ar-EG", ...)
  bool is_arabic = base::i18n::GetConfiguredLocale().starts_with("ar");
  return is_arabic ? kArabic : kEnglish;
}

std::u16string BlockedCountText(int count) {
  return base::i18n::MessageFormatter::FormatWithNumberedArgs(
      GetStrings().blocked_count, count);
}

// A host as people read it (Unicode, not punycode), kept left to right inside
// right-to-left text.
std::u16string HostForDisplay(std::string_view host) {
  return base::i18n::GetDisplayStringInLTRDirectionality(
      url_formatter::IDNToUnicode(host));
}

// The hoopoe, with a badge of the blocked count over its top corner: the
// curl, the mark's telling part, is at the bottom.
class BadgedHoopoe : public gfx::CanvasImageSource {
 public:
  BadgedHoopoe(int size, SkColor color, std::u16string badge)
      : gfx::CanvasImageSource(gfx::Size(size, size)),
        color_(color),
        badge_(std::move(badge)) {}

  // gfx::CanvasImageSource:
  void Draw(gfx::Canvas* canvas) override {
    gfx::PaintVectorIcon(canvas, kHoopoeIcon, size().width(), color_);
    if (badge_.empty()) {
      return;
    }

    const gfx::FontList& font = views::TypographyProvider::Get().GetFont(
        views::style::CONTEXT_BADGE, views::style::STYLE_SECONDARY);
    constexpr int kPadding = 2;
    int height = font.GetHeight();
    int text_width = gfx::Canvas::GetStringWidth(badge_, font);
    int width = std::max(height, text_width + 2 * kPadding);
    // the trailing corner, as the toolbar reads: right, or left in Arabic
    int x = base::i18n::IsRTL() ? 0 : size().width() - width;
    gfx::Rect badge(x, 0, width, height);

    cc::PaintFlags flags;
    flags.setAntiAlias(true);
    // A clear margin around the badge keeps it apart from the ring under it
    gfx::Rect cutout = badge;
    cutout.Inset(-1);
    flags.setBlendMode(SkBlendMode::kClear);
    canvas->DrawRoundRect(cutout, cutout.height() / 2, flags);

    // Ember, the mark's deep orange (files/hudhud/logo/README.md): white text
    // on it is readable (5:1), unlike on the lighter Flame
    constexpr SkColor kEmber = SkColorSetRGB(0xC2, 0x3A, 0x05);
    flags.setBlendMode(SkBlendMode::kSrcOver);
    flags.setColor(kEmber);
    canvas->DrawRoundRect(badge, height / 2, flags);
    canvas->DrawStringRectWithFlags(badge_, font, SK_ColorWHITE, badge,
                                    gfx::Canvas::TEXT_ALIGN_CENTER);
  }

 private:
  SkColor color_;
  std::u16string badge_;
};

// The count as the badge shows it: nothing for none, and no more than two
// digits, which is all a toolbar icon has room for.
std::u16string BadgeText(int count) {
  if (count == 0) {
    return std::u16string();
  }
  if (count > 99) {
    return base::FormatNumber(99) + u"+";
  }
  return base::FormatNumber(count);
}

}  // namespace

ShieldsToolbarButton::ShieldsToolbarButton(BrowserWindowInterface* browser)
    : ToolbarButton(base::BindRepeating(&ShieldsToolbarButton::OpenOrClosePanel,
                                        base::Unretained(this))),
      browser_(browser) {
  const Strings& strings = GetStrings();
  SetTooltipText(strings.shields);
  GetViewAccessibility().SetName(strings.shields);

  active_tab_subscription_ = browser->RegisterActiveTabDidChange(
      base::BindRepeating(&ShieldsToolbarButton::OnActiveTabChanged,
                          base::Unretained(this)));
  OnActiveTabChanged(browser);
}

ShieldsToolbarButton::~ShieldsToolbarButton() = default;

void ShieldsToolbarButton::UpdateIcon() {
  // Not in a window yet: OnThemeChanged() calls again once it is
  if (!GetColorProvider()) {
    return;
  }
  ShieldsTabHelper* helper = GetActiveTabHelper();
  bool is_enabled = GetEnabled();
  bool are_up = is_enabled && helper && helper->AreShieldsUpOnSite();

  // Shields down: the hoopoe greyed, and no count (nothing is blocked)
  std::u16string badge;
  if (are_up) {
    badge = BadgeText(helper->GetBlockedCount());
  }
  for (ButtonState state :
       {STATE_NORMAL, STATE_HOVERED, STATE_PRESSED, STATE_DISABLED}) {
    SkColor color = are_up ? GetForegroundColor(state)
                           : GetForegroundColor(STATE_DISABLED);
    gfx::ImageSkia icon(
        std::make_unique<BadgedHoopoe>(GetIconSize(), color, badge),
        gfx::Size(GetIconSize(), GetIconSize()));
    SetImageModel(state, ui::ImageModel::FromImageSkia(icon));
  }
}

void ShieldsToolbarButton::OnActiveTabChanged(BrowserWindowInterface* browser) {
  // The panel speaks of the tab it was opened on
  if (panel_) {
    panel_->Close();
  }

  tab_helper_subscription_ = {};
  ShieldsTabHelper* helper = GetActiveTabHelper();
  if (helper) {
    tab_helper_subscription_ = helper->RegisterChanged(base::BindRepeating(
        &ShieldsToolbarButton::Update, base::Unretained(this)));
  }
  Update();
}

void ShieldsToolbarButton::Update() {
  ShieldsTabHelper* helper = GetActiveTabHelper();
  // Shields act on web pages only: not on the new tab page, settings, files
  bool is_web_page = helper && helper->GetPageURL().SchemeIsHTTPOrHTTPS();
  SetEnabled(is_web_page);

  bool are_up = is_web_page && helper->AreShieldsUpOnSite();
  if (are_up) {
    GetViewAccessibility().SetDescription(
        BlockedCountText(helper->GetBlockedCount()));
  } else {
    GetViewAccessibility().RemoveDescription();
  }
  UpdateIcon();
}

void ShieldsToolbarButton::OpenOrClosePanel() {
  if (panel_) {
    panel_->Close();
    return;
  }
  ShieldsTabHelper* helper = GetActiveTabHelper();
  if (!helper) {
    return;
  }

  const Strings& strings = GetStrings();
  bool are_up = helper->AreShieldsUpOnSite();
  std::u16string what_is_blocked =
      are_up ? BlockedCountText(helper->GetBlockedCount())
             : std::u16string(strings.shields_down);

  ui::DialogModel::Builder panel;
  panel.SetTitle(HostForDisplay(helper->GetPageURL().host()))
      .AddParagraph(ui::DialogModelLabel(what_is_blocked));

  constexpr size_t kHostsShown = 5;
  std::vector<std::string> hosts = helper->GetMostBlockedHosts(kHostsShown);
  if (!hosts.empty()) {
    std::u16string host_lines;
    for (const std::string& host : hosts) {
      if (!host_lines.empty()) {
        host_lines += u"\n";
      }
      host_lines += HostForDisplay(host);
    }
    panel.AddParagraph(ui::DialogModelLabel(host_lines), strings.most_blocked);
  }

  // The switch: a dialog model has checkboxes but no switch, so it is a row
  // of plain views
  auto row = std::make_unique<views::View>();
  auto* layout = row->SetLayoutManager(std::make_unique<views::BoxLayout>(
      views::BoxLayout::Orientation::kHorizontal, gfx::Insets(),
      /*between_child_spacing=*/12));
  layout->set_cross_axis_alignment(
      views::BoxLayout::CrossAxisAlignment::kCenter);
  auto* label =
      row->AddChildView(std::make_unique<views::Label>(strings.switch_label));
  label->SetHorizontalAlignment(gfx::ALIGN_LEFT);
  layout->SetFlexForView(label, 1);
  auto* toggle = row->AddChildView(std::make_unique<views::ToggleButton>(
      base::BindRepeating(&ShieldsToolbarButton::FlipShields,
                          weak_factory_.GetWeakPtr())));
  toggle->SetIsOn(are_up);
  toggle->GetViewAccessibility().SetName(strings.switch_label);
  panel.AddCustomField(
      std::make_unique<views::BubbleDialogModelHost::CustomView>(
          std::move(row), views::BubbleDialogModelHost::FieldType::kControl,
          toggle));

  auto host = std::make_unique<views::BubbleDialogModelHost>(
      panel.Build(), this, views::BubbleBorder::TOP_RIGHT);
  // As Chromium's own toolbar bubbles (battery saver, memory saver) are made:
  // the widget owns itself and the panel, and closes when it loses focus
  views::Widget* widget = views::BubbleDialogDelegate::CreateBubbleDeprecated(
      std::move(host), views::Widget::InitParams::NATIVE_WIDGET_OWNS_WIDGET);
  panel_ = widget->GetWeakPtr();
  widget->Show();
}

void ShieldsToolbarButton::FlipShields() {
  // The panel's tab: the panel closes whenever another tab becomes active
  ShieldsTabHelper* helper = GetActiveTabHelper();
  if (helper) {
    helper->SetShieldsUpOnSite(!helper->AreShieldsUpOnSite());
  }
  // What the panel said is now out of date; the reloaded page counts anew
  if (panel_) {
    panel_->Close();
  }
}

ShieldsTabHelper* ShieldsToolbarButton::GetActiveTabHelper() {
  tabs::TabInterface* tab = browser_->GetActiveTabInterface();
  if (!tab || !tab->GetContents()) {
    return nullptr;
  }
  return ShieldsTabHelper::FromWebContents(tab->GetContents());
}

BEGIN_METADATA(ShieldsToolbarButton)
END_METADATA

}  // namespace hudhud_shields
