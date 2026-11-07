/* buna-kiosk's C interface to aquamarine (docs/kiosk.md, "The shim").
 *
 * The shim owns every aquamarine object.  Rust holds plain numbers for
 * outputs and never gets a callback: aquamarine's signals only append an
 * aq_event to a queue, which Rust drains with aq_next_event() after every
 * call into the shim. */
#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct aq_kiosk aq_kiosk;

/* Event kinds.  The numbers are part of the interface: src/aq.rs has the
 * same ones. */
#define AQ_EVENT_NEW_OUTPUT 1         /* output */
#define AQ_EVENT_OUTPUT_GONE 2        /* output */
#define AQ_EVENT_OUTPUT_FRAME 3       /* output: it can take the next frame */
#define AQ_EVENT_OUTPUT_RECONFIGURE 4 /* output: its mode must be set again */
#define AQ_EVENT_KEY 5                /* key (evdev code), pressed */
#define AQ_EVENT_SESSION_ACTIVE 6     /* this VT is ours again */
#define AQ_EVENT_SESSION_INACTIVE 7   /* another VT is shown: commit nothing */

struct aq_event {
    uint32_t kind;
    uint32_t output;
    uint32_t key;
    bool pressed;
};

/* The DRM backend, with its seat session (libseat).  NULL on failure. */
aq_kiosk* aq_create(void);
/* Opens the screens and input devices; new outputs arrive as events. */
bool aq_start(aq_kiosk* kiosk);

/* The file descriptors to poll now; aq_dispatch() one when it is
 * readable. */
size_t aq_poll_fds(aq_kiosk* kiosk, int* fds, size_t max);
void aq_dispatch(aq_kiosk* kiosk, int fd);
bool aq_next_event(aq_kiosk* kiosk, struct aq_event* event);

/* Sets the output to be turned on at its preferred mode, with a swapchain
 * for it; the next commit (aq_output_fill) applies it.  Writes the mode's
 * size. */
bool aq_output_enable(aq_kiosk* kiosk, uint32_t output, int32_t* width, int32_t* height);
/* The output's connector name, like "eDP-1": valid until its
 * AQ_EVENT_OUTPUT_GONE. */
const char* aq_output_name(aq_kiosk* kiosk, uint32_t output);
/* Phase 1's whole renderer: fills the next buffer with one colour
 * (0xRRGGBB) through a CPU mapping, and commits it. */
bool aq_output_fill(aq_kiosk* kiosk, uint32_t output, uint32_t rgb);
/* Asks aquamarine for an AQ_EVENT_OUTPUT_FRAME on the output. */
void aq_output_schedule_frame(aq_kiosk* kiosk, uint32_t output);

bool aq_session_active(aq_kiosk* kiosk);
bool aq_switch_vt(aq_kiosk* kiosk, uint32_t vt);

/* There is no aq_destroy(): destroying the backend turns every screen
 * off, and the kiosk must leave its last picture lit when it exits
 * (docs/kiosk.md, "Leaving the screen lit").  The process exits instead. */

#ifdef __cplusplus
}
#endif
