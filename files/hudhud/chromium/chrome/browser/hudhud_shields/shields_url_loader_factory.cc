// Buna Browser's Shields (bunix: docs/browser.md, "Shields").

#include "chrome/browser/buna_shields/shields_url_loader_factory.h"

#include <string_view>
#include <utility>

#include "base/memory/scoped_refptr.h"
#include "base/memory/self_deleting.h"
#include "chrome/browser/buna_shields/shields_engine.h"
#include "chrome/browser/content_settings/host_content_settings_map_factory.h"
#include "components/content_settings/core/browser/host_content_settings_map.h"
#include "mojo/public/cpp/base/big_buffer.h"
#include "mojo/public/cpp/bindings/remote.h"
#include "mojo/public/cpp/bindings/self_owned_receiver.h"
#include "net/base/isolation_info.h"
#include "net/base/net_errors.h"
#include "net/url_request/redirect_info.h"
#include "services/network/public/cpp/resource_request.h"
#include "services/network/public/cpp/self_deleting_url_loader_factory.h"
#include "services/network/public/cpp/url_loader_completion_status.h"
#include "services/network/public/cpp/url_loader_factory_builder.h"
#include "services/network/public/mojom/early_hints.mojom.h"
#include "services/network/public/mojom/fetch_api.mojom.h"
#include "services/network/public/mojom/url_loader.mojom.h"
#include "services/network/public/mojom/url_response_head.mojom.h"
#include "url/origin.h"

namespace buna_shields {

namespace {

using FactoryType = content::ContentBrowserClient::URLLoaderFactoryType;
using Destination = network::mojom::RequestDestination;

// adblock-rust's name for what a request loads; filter list options such as
// $script or $image match these.
std::string_view RequestType(Destination destination) {
  switch (destination) {
    case Destination::kScript:
    case Destination::kWorker:
    case Destination::kSharedWorker:
    case Destination::kServiceWorker:
    case Destination::kAudioWorklet:
    case Destination::kPaintWorklet:
      return "script";
    case Destination::kImage:
      return "image";
    case Destination::kStyle:
    case Destination::kXslt:
      return "stylesheet";
    case Destination::kFont:
      return "font";
    case Destination::kAudio:
    case Destination::kVideo:
    case Destination::kTrack:
      return "media";
    case Destination::kFrame:
    case Destination::kIframe:
    case Destination::kFencedframe:
      return "sub_frame";
    case Destination::kEmpty:
      // fetch() and XMLHttpRequest
      return "xhr";
    case Destination::kObject:
    case Destination::kEmbed:
      return "object";
    case Destination::kReport:
      return "ping";
    default:
      return "other";
  }
}

// What the filter lists are asked about a request, besides its URL.
struct RequestContext {
  // whether a request is third-party is decided against the document that
  // makes it (an ad frame's own requests are its own)
  GURL source;
  std::string_view request_type;
};

// Fails a request the way every ad blocker does.
void FailAsBlocked(network::mojom::URLLoaderClient& client) {
  client.OnComplete(
      network::URLLoaderCompletionStatus(net::ERR_BLOCKED_BY_CLIENT));
}

// Sits between the network's loader and the page, for one request whose
// first URL the lists allowed: a redirect to a URL they block is stopped
// here (a tracking pixel that redirects to an analytics server).  Every
// other message passes through as it is.  Lives as long as the request.
class RedirectChecker : public network::mojom::URLLoaderClient {
 public:
  RedirectChecker(mojo::PendingRemote<network::mojom::URLLoaderClient> page,
                  RequestContext context)
      : page_(std::move(page)), context_(std::move(context)) {}

  // network::mojom::URLLoaderClient:
  void OnReceiveRedirect(const net::RedirectInfo& redirect_info,
                         network::mojom::URLResponseHeadPtr head) override {
    if (!page_) {
      return;
    }
    bool is_blocked = ShieldsEngine::Get().ShouldBlock(
        redirect_info.new_url, context_.source, context_.request_type);
    if (is_blocked) {
      // The page drops the request, which closes the network's loader and,
      // with it, this checker.
      FailAsBlocked(*page_);
      page_.reset();
      return;
    }
    page_->OnReceiveRedirect(redirect_info, std::move(head));
  }

  void OnReceiveEarlyHints(network::mojom::EarlyHintsPtr early_hints) override {
    if (page_) {
      page_->OnReceiveEarlyHints(std::move(early_hints));
    }
  }

  void OnReceiveResponse(
      network::mojom::URLResponseHeadPtr head,
      mojo::ScopedDataPipeConsumerHandle body,
      std::optional<mojo_base::BigBuffer> cached_metadata) override {
    if (page_) {
      page_->OnReceiveResponse(std::move(head), std::move(body),
                               std::move(cached_metadata));
    }
  }

  void OnUploadProgress(int64_t current_position,
                        int64_t total_size,
                        OnUploadProgressCallback callback) override {
    if (page_) {
      page_->OnUploadProgress(current_position, total_size,
                              std::move(callback));
    }
  }

  void OnTransferSizeUpdated(int32_t transfer_size_diff) override {
    if (page_) {
      page_->OnTransferSizeUpdated(transfer_size_diff);
    }
  }

  void OnComplete(const network::URLLoaderCompletionStatus& status) override {
    if (page_) {
      page_->OnComplete(status);
    }
  }

 private:
  // the page's end; reset once a redirect was blocked
  mojo::Remote<network::mojom::URLLoaderClient> page_;
  RequestContext context_;
};

// Sits in front of the factory that reaches the network, for one document
// or worker.  Lives on the UI thread, as long as the pipe to it.
class ShieldsURLLoaderFactory : public network::SelfDeletingURLLoaderFactory {
 public:
  ShieldsURLLoaderFactory(
      mojo::PendingReceiver<network::mojom::URLLoaderFactory> receiver,
      mojo::PendingRemote<network::mojom::URLLoaderFactory> target,
      scoped_refptr<HostContentSettingsMap> settings,
      const url::Origin& top_frame_origin,
      base::SelfDeletingPassKey key)
      : network::SelfDeletingURLLoaderFactory(std::move(receiver), key),
        target_(std::move(target)),
        settings_(std::move(settings)),
        top_frame_origin_(top_frame_origin) {
    target_.set_disconnect_handler(
        base::BindOnce(&ShieldsURLLoaderFactory::DisconnectReceiversAndDestroy,
                       base::Unretained(this)));
  }

  // network::mojom::URLLoaderFactory:
  void CreateLoaderAndStart(
      mojo::PendingReceiver<network::mojom::URLLoader> loader,
      int32_t request_id,
      uint32_t options,
      const network::ResourceRequest& request,
      mojo::PendingRemote<network::mojom::URLLoaderClient> client,
      const net::MutableNetworkTrafficAnnotationTag& traffic_annotation)
      override {
    std::optional<RequestContext> context = ContextIfShielded(request);
    if (!context) {
      target_->CreateLoaderAndStart(std::move(loader), request_id, options,
                                    request, std::move(client),
                                    traffic_annotation);
      return;
    }

    bool is_blocked = ShieldsEngine::Get().ShouldBlock(
        request.url, context->source, context->request_type);
    if (is_blocked) {
      mojo::Remote<network::mojom::URLLoaderClient> page(std::move(client));
      FailAsBlocked(*page);
      return;
    }

    mojo::PendingRemote<network::mojom::URLLoaderClient> checker;
    mojo::MakeSelfOwnedReceiver(
        std::make_unique<RedirectChecker>(std::move(client),
                                          std::move(*context)),
        checker.InitWithNewPipeAndPassReceiver());
    target_->CreateLoaderAndStart(std::move(loader), request_id, options,
                                  request, std::move(checker),
                                  traffic_annotation);
  }

 private:
  using SelfDeletingURLLoaderFactory::DisconnectReceiversAndDestroy;

  ~ShieldsURLLoaderFactory() override = default;

  // Empty for the requests Shields leave alone: not web requests, a tab's
  // own page, and every request on a site the user turned Shields down for.
  std::optional<RequestContext> ContextIfShielded(
      const network::ResourceRequest& request) const {
    bool is_web_request = request.url.SchemeIsHTTPOrHTTPS();
    bool is_page_itself = request.destination == Destination::kDocument;
    if (!is_web_request || is_page_itself) {
      return std::nullopt;
    }
    GURL site = TopFrameOrigin(request).GetURL();
    if (!AreShieldsUp(*settings_, site)) {
      return std::nullopt;
    }

    // A sandboxed frame's origin is opaque; the site it came from still
    // decides which rules (and exceptions) apply.
    GURL source;
    if (request.request_initiator) {
      source = request.request_initiator->GetTupleOrPrecursorTupleIfOpaque()
                   .GetURL();
    }
    if (source.is_empty()) {
      source = site;
    }
    return RequestContext{source, RequestType(request.destination)};
  }

  // Navigations (of frames inside the tab) carry their own isolation info;
  // a document's other requests share the one its factory was made with.
  url::Origin TopFrameOrigin(const network::ResourceRequest& request) const {
    if (request.trusted_params) {
      const std::optional<url::Origin>& origin =
          request.trusted_params->isolation_info.top_frame_origin();
      if (origin) {
        return *origin;
      }
    }
    return top_frame_origin_;
  }

  mojo::Remote<network::mojom::URLLoaderFactory> target_;
  scoped_refptr<HostContentSettingsMap> settings_;
  url::Origin top_frame_origin_;
};

}  // namespace

void MaybeProxyURLLoaderFactory(
    content::BrowserContext* browser_context,
    FactoryType type,
    const net::IsolationInfo& isolation_info,
    network::URLLoaderFactoryBuilder& factory_builder) {
  // What web content loads; not downloads, prefetches or DevTools.
  bool is_web_content =
      type == FactoryType::kNavigation ||
      type == FactoryType::kDocumentSubResource ||
      type == FactoryType::kWorkerMainResource ||
      type == FactoryType::kWorkerSubResource ||
      type == FactoryType::kServiceWorkerScript ||
      type == FactoryType::kServiceWorkerSubResource;
  if (!is_web_content) {
    return;
  }

  // The first page's factories are made at start-up
  ShieldsEngine::StartLoading();

  auto [receiver, target] = factory_builder.Append();
  base::MakeSelfDeleting<ShieldsURLLoaderFactory>(
      std::move(receiver), std::move(target),
      base::WrapRefCounted(
          HostContentSettingsMapFactory::GetForProfile(browser_context)),
      isolation_info.top_frame_origin().value_or(url::Origin()));
}

}  // namespace buna_shields
