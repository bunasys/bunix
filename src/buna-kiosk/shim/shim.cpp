// buna-kiosk's shim: the one place that calls aquamarine (docs/kiosk.md,
// "The shim").  It owns every aquamarine object and signal listener.
// aquamarine fires its signals inside the calls that cause them (new
// outputs inside start(), frames inside commit()), so a listener here only
// queues a plain aq_event; Rust drains the queue after each call, outside
// aquamarine.  No C++ exception crosses into Rust: every entry point
// catches.
#include "shim.h"

#include <aquamarine/allocator/Swapchain.hpp>
#include <aquamarine/backend/Backend.hpp>
#include <aquamarine/input/Input.hpp>
#include <aquamarine/output/Output.hpp>
#include <gbm.h>

#include <cstdio>
#include <cstdlib>
#include <deque>
#include <map>
#include <vector>

using Hyprutils::Memory::CSharedPointer;
using Hyprutils::Memory::CWeakPointer;
using Hyprutils::Signal::CHyprSignalListener;

namespace {

// one buffer on screen, one waiting to be shown, one being drawn
constexpr size_t SWAPCHAIN_LENGTH = 3;

struct Output {
    CSharedPointer<Aquamarine::IOutput> output;
    std::vector<CHyprSignalListener>    listeners;
};

struct Keyboard {
    CWeakPointer<Aquamarine::IKeyboard> keyboard;
    std::vector<CHyprSignalListener>    listeners;
};

const char* levelName(Aquamarine::eBackendLogLevel level) {
    switch (level) {
        case Aquamarine::AQ_LOG_TRACE: return "trace";
        case Aquamarine::AQ_LOG_DEBUG: return "debug";
        case Aquamarine::AQ_LOG_WARNING: return "warning";
        case Aquamarine::AQ_LOG_ERROR: return "error";
        case Aquamarine::AQ_LOG_CRITICAL: return "critical";
    }
    return "?";
}

void reportException(const char* call) {
    try {
        throw;
    } catch (const std::exception& e) {
        std::fprintf(stderr, "buna-kiosk: %s: %s\n", call, e.what());
    } catch (...) {
        std::fprintf(stderr, "buna-kiosk: %s: an unknown C++ exception\n", call);
    }
}

} // namespace

struct aq_kiosk {
    CSharedPointer<Aquamarine::CBackend> backend;
    std::deque<aq_event>                 events;
    std::map<uint32_t, Output>           outputs;
    std::vector<uint32_t>                goneOutputs;
    uint32_t                             nextOutput = 1;
    std::vector<Keyboard>                keyboards;
    std::vector<CHyprSignalListener>     listeners;

    void queue(uint32_t kind, uint32_t output = 0) {
        events.push_back(aq_event{.kind = kind, .output = output, .key = 0, .pressed = false});
    }

    void queueKey(uint32_t key, bool pressed) {
        events.push_back(aq_event{.kind = AQ_EVENT_KEY, .output = 0, .key = key, .pressed = pressed});
    }

    // Listeners cannot be destroyed while their own signal is being
    // emitted, so whatever is gone is dropped here, between calls
    void dropGone() {
        for (uint32_t id : goneOutputs)
            outputs.erase(id);
        goneOutputs.clear();
        std::erase_if(keyboards, [](const Keyboard& k) { return k.keyboard.expired(); });
    }

    void addOutput(CSharedPointer<Aquamarine::IOutput> output) {
        const uint32_t id = nextOutput++;
        Output         entry{.output = output, .listeners = {}};
        // aquamarine sends its redraw requests (scheduleFrame) as frames too
        entry.listeners.push_back(output->events.frame.listen([this, id] { queue(AQ_EVENT_OUTPUT_FRAME, id); }));
        entry.listeners.push_back(output->events.state.listen([this, id](const Aquamarine::IOutput::SStateEvent& event) {
            // a size of 0x0 means the output lost its mode
            const bool lostItsMode = event.size.x == 0 && event.size.y == 0;
            if (lostItsMode)
                queue(AQ_EVENT_OUTPUT_RECONFIGURE, id);
        }));
        entry.listeners.push_back(output->events.destroy.listen([this, id] {
            goneOutputs.push_back(id);
            queue(AQ_EVENT_OUTPUT_GONE, id);
        }));
        outputs.emplace(id, std::move(entry));
        queue(AQ_EVENT_NEW_OUTPUT, id);
    }

    void addKeyboard(CSharedPointer<Aquamarine::IKeyboard> keyboard) {
        Keyboard entry{.keyboard = keyboard, .listeners = {}};
        entry.listeners.push_back(
            keyboard->events.key.listen([this](const Aquamarine::IKeyboard::SKeyEvent& event) { queueKey(event.key, event.pressed); }));
        keyboards.push_back(std::move(entry));
    }

    Aquamarine::IOutput* find(uint32_t id) {
        auto it = outputs.find(id);
        return it == outputs.end() ? nullptr : it->second.output.get();
    }

    bool hasSession() {
        return backend->hasSession() && backend->session;
    }
};

extern "C" {

aq_kiosk* aq_create(void) {
    try {
        Aquamarine::SBackendOptions options;
        const bool                  debug = std::getenv("BUNA_KIOSK_DEBUG") != nullptr;
        options.logFunction               = [debug](Aquamarine::eBackendLogLevel level, std::string message) {
            const bool worthShowing = debug || level >= Aquamarine::AQ_LOG_WARNING;
            if (worthShowing)
                std::fprintf(stderr, "aquamarine %s: %s\n", levelName(level), message.c_str());
        };

        // Only the DRM backend: buna-kiosk always owns the screens itself
        Aquamarine::SBackendImplementationOptions drm;
        drm.backendType        = Aquamarine::AQ_BACKEND_DRM;
        drm.backendRequestMode = Aquamarine::AQ_BACKEND_REQUEST_MANDATORY;

        auto backend = Aquamarine::CBackend::create({drm}, options);
        if (!backend)
            return nullptr;

        auto* kiosk    = new aq_kiosk;
        kiosk->backend = backend;
        kiosk->listeners.push_back(backend->events.newOutput.listen([kiosk](CSharedPointer<Aquamarine::IOutput> output) { kiosk->addOutput(output); }));
        kiosk->listeners.push_back(backend->events.newKeyboard.listen([kiosk](CSharedPointer<Aquamarine::IKeyboard> keyboard) { kiosk->addKeyboard(keyboard); }));
        return kiosk;
    } catch (...) {
        reportException("aq_create");
        return nullptr;
    }
}

bool aq_start(aq_kiosk* kiosk) {
    try {
        if (!kiosk->backend->start())
            return false;
        if (kiosk->hasSession()) {
            kiosk->listeners.push_back(kiosk->backend->session->events.changeActive.listen([kiosk] {
                const bool active = kiosk->backend->session->active;
                kiosk->queue(active ? AQ_EVENT_SESSION_ACTIVE : AQ_EVENT_SESSION_INACTIVE);
            }));
        }
        return true;
    } catch (...) {
        reportException("aq_start");
        return false;
    }
}

size_t aq_poll_fds(aq_kiosk* kiosk, int* fds, size_t max) {
    try {
        size_t count = 0;
        for (const auto& pollFd : kiosk->backend->getPollFDs()) {
            if (count == max)
                break;
            fds[count++] = pollFd->fd;
        }
        return count;
    } catch (...) {
        reportException("aq_poll_fds");
        return 0;
    }
}

void aq_dispatch(aq_kiosk* kiosk, int fd) {
    try {
        kiosk->dropGone();
        // the fds as they are now: one that went away is not dispatched
        for (const auto& pollFd : kiosk->backend->getPollFDs()) {
            if (pollFd->fd == fd && pollFd->onSignal)
                pollFd->onSignal();
        }
    } catch (...) {
        reportException("aq_dispatch");
    }
}

bool aq_next_event(aq_kiosk* kiosk, aq_event* event) {
    if (kiosk->events.empty())
        return false;
    *event = kiosk->events.front();
    kiosk->events.pop_front();
    return true;
}

bool aq_output_enable(aq_kiosk* kiosk, uint32_t id, int32_t* width, int32_t* height) {
    try {
        auto* output = kiosk->find(id);
        if (!output || !output->swapchain)
            return false;
        auto mode = output->preferredMode();
        if (!mode && !output->modes.empty())
            mode = output->modes.front();
        if (!mode)
            return false;

        output->state->setEnabled(true);
        output->state->setMode(mode);
        output->state->setFormat(DRM_FORMAT_XRGB8888);

        // From the swapchain's own options: aquamarine sets some itself
        // (multigpu, for a screen on a second GPU)
        auto options          = output->swapchain->currentOptions();
        options.length        = SWAPCHAIN_LENGTH;
        options.size          = mode->pixelSize;
        options.format        = DRM_FORMAT_XRGB8888;
        options.scanout       = true;
        options.scanoutOutput = kiosk->outputs.at(id).output;
        if (!output->swapchain->reconfigure(options))
            return false;

        *width  = (int32_t)mode->pixelSize.x;
        *height = (int32_t)mode->pixelSize.y;
        return true;
    } catch (...) {
        reportException("aq_output_enable");
        return false;
    }
}

const char* aq_output_name(aq_kiosk* kiosk, uint32_t id) {
    auto* output = kiosk->find(id);
    return output ? output->name.c_str() : "";
}

bool aq_output_fill(aq_kiosk* kiosk, uint32_t id, uint32_t rgb) {
    try {
        auto* output = kiosk->find(id);
        if (!output || !output->swapchain)
            return false;
        auto buffer = output->swapchain->next(nullptr);
        if (!buffer)
            return false;

        auto [pixels, format, length] = buffer->beginDataPtr(GBM_BO_TRANSFER_WRITE);
        if (!pixels)
            return false;
        // XRGB8888: one little-endian 32-bit word per pixel, the padding at
        // the end of each row included (one colour needs no row maths)
        const uint32_t pixel = 0xff000000u | rgb;
        auto*          words = reinterpret_cast<uint32_t*>(pixels);
        for (size_t i = 0; i < length / 4; i++)
            words[i] = pixel;
        buffer->endDataPtr();

        output->state->setBuffer(buffer);
        return output->commit();
    } catch (...) {
        reportException("aq_output_fill");
        return false;
    }
}

bool aq_session_active(aq_kiosk* kiosk) {
    return kiosk->hasSession() ? kiosk->backend->session->active : true;
}

bool aq_switch_vt(aq_kiosk* kiosk, uint32_t vt) {
    try {
        return kiosk->hasSession() && kiosk->backend->session->switchVT(vt);
    } catch (...) {
        reportException("aq_switch_vt");
        return false;
    }
}

} // extern "C"
