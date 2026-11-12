// Hudhud's Shields (bunix: docs/browser.md, "Shields").

#ifndef CHROME_BROWSER_UI_VIEWS_HUDHUD_SHIELDS_HOOPOE_ICON_H_
#define CHROME_BROWSER_UI_VIEWS_HUDHUD_SHIELDS_HOOPOE_ICON_H_

namespace gfx {
struct VectorIcon;
}

namespace hudhud_shields {

// The hoopoe, Hudhud's mark, as a vector icon drawn in whatever color the
// toolbar uses.  Never mirrored in right-to-left languages: a mark keeps its
// shape.  Generated (hoopoe_icon.cc) by files/hudhud/logo/vector_icon.py.
extern const gfx::VectorIcon kHoopoeIcon;

}  // namespace hudhud_shields

#endif  // CHROME_BROWSER_UI_VIEWS_HUDHUD_SHIELDS_HOOPOE_ICON_H_
