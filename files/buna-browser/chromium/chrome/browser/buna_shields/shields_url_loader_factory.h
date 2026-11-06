// Buna Browser's Shields (bunix: docs/browser.md, "Shields").

#ifndef CHROME_BROWSER_BUNA_SHIELDS_SHIELDS_URL_LOADER_FACTORY_H_
#define CHROME_BROWSER_BUNA_SHIELDS_SHIELDS_URL_LOADER_FACTORY_H_

#include "content/public/browser/content_browser_client.h"

namespace content {
class BrowserContext;
}

namespace net {
class IsolationInfo;
}

namespace network {
class URLLoaderFactoryBuilder;
}

namespace buna_shields {

// Puts Shields between web pages (and their workers) and the network:
// requests the filter lists block fail with ERR_BLOCKED_BY_CLIENT, unless
// the user turned Shields down for the tab's site.  A page's own navigation
// is never blocked.  Called from
// ChromeContentBrowserClient::WillCreateURLLoaderFactory.
void MaybeProxyURLLoaderFactory(
    content::BrowserContext* browser_context,
    content::ContentBrowserClient::URLLoaderFactoryType type,
    const net::IsolationInfo& isolation_info,
    network::URLLoaderFactoryBuilder& factory_builder);

}  // namespace buna_shields

#endif  // CHROME_BROWSER_BUNA_SHIELDS_SHIELDS_URL_LOADER_FACTORY_H_
