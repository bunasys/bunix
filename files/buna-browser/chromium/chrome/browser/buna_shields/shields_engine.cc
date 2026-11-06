// Buna Browser's Shields (bunix: docs/browser.md, "Shields").

#include "chrome/browser/buna_shields/shields_engine.h"

#include <string>
#include <utility>

#include "base/base_paths.h"
#include "base/files/file_path.h"
#include "base/files/file_util.h"
#include "base/json/json_reader.h"
#include "base/json/json_writer.h"
#include "base/logging.h"
#include "base/native_library.h"
#include "base/path_service.h"
#include "base/task/thread_pool.h"
// The engine's C interface.  Copied in from files/buna-browser/shields/
// include by base/chromium.bst, rather than taken from the installed
// engine, so that a filter-list change does not rebuild Chromium.
#include "chrome/browser/buna_shields/buna_shields.h"
#include "components/content_settings/core/browser/host_content_settings_map.h"
#include "components/content_settings/core/common/content_settings.h"
#include "components/content_settings/core/common/content_settings_types.h"

namespace buna_shields {

struct ShieldsEngine::Functions {
  decltype(&buna_shields_load) load;
  decltype(&buna_shields_should_block) should_block;
  decltype(&buna_shields_page_resources) page_resources;
  decltype(&buna_shields_hidden_selectors) hidden_selectors;
  decltype(&buna_shields_free_string) free_string;
};

namespace {

// Parses a JSON string the library returned, and frees it.  Empty if the
// library gave nothing back.
std::optional<base::Value> TakeJson(
    char* json,
    decltype(&buna_shields_free_string) free_string) {
  if (!json) {
    return std::nullopt;
  }
  std::optional<base::Value> value =
      base::JSONReader::Read(json, base::JSON_PARSE_RFC);
  free_string(json);
  return value;
}

std::string ToJson(const base::ListValue& list) {
  return base::WriteJson(list).value_or("[]");
}

std::vector<std::string> ToStrings(const base::ListValue& list) {
  std::vector<std::string> strings;
  for (const base::Value& item : list) {
    if (item.is_string()) {
      strings.push_back(item.GetString());
    }
  }
  return strings;
}

}  // namespace

ShieldsEngine::PageResources::PageResources() = default;
ShieldsEngine::PageResources::PageResources(PageResources&&) = default;
ShieldsEngine::PageResources::~PageResources() = default;

// static
ShieldsEngine& ShieldsEngine::Get() {
  static base::NoDestructor<ShieldsEngine> engine;
  return *engine;
}

// static
void ShieldsEngine::StartLoading() {
  Get();
}

// The engine is made once, by the first StartLoading() or Get(): this is
// where its loading starts.
ShieldsEngine::ShieldsEngine() {
  base::ThreadPool::PostTask(
      FROM_HERE, {base::MayBlock(), base::TaskPriority::USER_BLOCKING},
      base::BindOnce(&ShieldsEngine::Load, base::Unretained(this)));
}

// Never runs: the engine lives as long as the browser.
ShieldsEngine::~ShieldsEngine() = default;

void ShieldsEngine::Load() {
  base::FilePath browser_dir;
  if (!base::PathService::Get(base::DIR_MODULE, &browser_dir)) {
    return;
  }

  base::NativeLibraryLoadError error;
  base::NativeLibrary library = base::LoadNativeLibrary(
      browser_dir.Append("libbuna_shields.so"), &error);
  if (!library) {
    LOG(ERROR) << "Shields are off: " << error.ToString();
    return;
  }
  // The library stays loaded for the life of the browser.
  Functions functions{
      reinterpret_cast<decltype(Functions::load)>(
          base::GetFunctionPointerFromNativeLibrary(library,
                                                    "buna_shields_load")),
      reinterpret_cast<decltype(Functions::should_block)>(
          base::GetFunctionPointerFromNativeLibrary(
              library, "buna_shields_should_block")),
      reinterpret_cast<decltype(Functions::page_resources)>(
          base::GetFunctionPointerFromNativeLibrary(
              library, "buna_shields_page_resources")),
      reinterpret_cast<decltype(Functions::hidden_selectors)>(
          base::GetFunctionPointerFromNativeLibrary(
              library, "buna_shields_hidden_selectors")),
      reinterpret_cast<decltype(Functions::free_string)>(
          base::GetFunctionPointerFromNativeLibrary(
              library, "buna_shields_free_string")),
  };
  bool has_all_functions = functions.load && functions.should_block &&
                           functions.page_resources &&
                           functions.hidden_selectors &&
                           functions.free_string;
  if (!has_all_functions) {
    LOG(ERROR) << "Shields are off: libbuna_shields.so is incomplete";
    return;
  }

  std::string data;
  if (!base::ReadFileToString(browser_dir.Append("shields.dat"), &data)) {
    LOG(ERROR) << "Shields are off: shields.dat cannot be read";
    return;
  }
  BunaShields* engine = functions.load(
      reinterpret_cast<const uint8_t*>(data.data()), data.size());
  if (!engine) {
    LOG(ERROR) << "Shields are off: shields.dat is not an engine file";
    return;
  }

  functions_ = new Functions(functions);
  // release: whoever sees the engine also sees `functions_`
  engine_.store(engine, std::memory_order_release);
}

bool ShieldsEngine::ShouldBlock(const GURL& url,
                                const GURL& source,
                                std::string_view request_type) const {
  BunaShields* engine = engine_.load(std::memory_order_acquire);
  if (!engine) {
    return false;
  }
  return functions_->should_block(engine, url.spec().c_str(),
                                  source.spec().c_str(),
                                  std::string(request_type).c_str());
}

std::optional<ShieldsEngine::PageResources> ShieldsEngine::GetPageResources(
    const GURL& url) const {
  BunaShields* engine = engine_.load(std::memory_order_acquire);
  if (!engine) {
    return std::nullopt;
  }
  std::optional<base::Value> json =
      TakeJson(functions_->page_resources(engine, url.spec().c_str()),
               functions_->free_string);
  if (!json || !json->is_dict()) {
    return std::nullopt;
  }

  base::DictValue& dict = json->GetDict();
  PageResources resources;
  if (base::ListValue* selectors = dict.FindList("hide_selectors")) {
    resources.hide_selectors = ToStrings(*selectors);
  }
  if (base::ListValue* exceptions = dict.FindList("exceptions")) {
    resources.exceptions = std::move(*exceptions);
  }
  resources.generichide = dict.FindBool("generichide").value_or(false);
  return resources;
}

std::vector<std::string> ShieldsEngine::GetHiddenSelectors(
    const base::ListValue& classes,
    const base::ListValue& ids,
    const base::ListValue& exceptions) const {
  BunaShields* engine = engine_.load(std::memory_order_acquire);
  if (!engine) {
    return {};
  }
  std::optional<base::Value> json = TakeJson(
      functions_->hidden_selectors(engine, ToJson(classes).c_str(),
                                   ToJson(ids).c_str(),
                                   ToJson(exceptions).c_str()),
      functions_->free_string);
  if (!json || !json->is_list()) {
    return {};
  }
  return ToStrings(json->GetList());
}

bool AreShieldsUp(const HostContentSettingsMap& settings, const GURL& site) {
  return settings.GetContentSetting(site, GURL(), ContentSettingsType::ADS) ==
         CONTENT_SETTING_BLOCK;
}

}  // namespace buna_shields
