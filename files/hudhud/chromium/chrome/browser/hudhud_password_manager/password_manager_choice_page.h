// Hudhud's password manager choice (bunix: docs/browser.md, "Password manager").

#ifndef CHROME_BROWSER_HUDHUD_PASSWORD_MANAGER_PASSWORD_MANAGER_CHOICE_PAGE_H_
#define CHROME_BROWSER_HUDHUD_PASSWORD_MANAGER_PASSWORD_MANAGER_CHOICE_PAGE_H_

namespace content {
class WebUI;
class WebUIDataSource;
}  // namespace content

namespace hudhud_password_manager {

// Lets chrome://password-manager show and change the choice (its
// <hudhud-password-manager-choice> element): adds the element's English or
// Arabic strings to `source` and the handler for its messages to `web_ui`.
void AddChoiceToPage(content::WebUI* web_ui, content::WebUIDataSource* source);

}  // namespace hudhud_password_manager

#endif  // CHROME_BROWSER_HUDHUD_PASSWORD_MANAGER_PASSWORD_MANAGER_CHOICE_PAGE_H_
