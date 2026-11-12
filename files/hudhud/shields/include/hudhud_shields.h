// Hudhud's Shields engine (src/lib.rs, which documents each call).
// Strings are NUL-terminated UTF-8; lists are JSON.  Strings returned by
// these functions are freed with hudhud_shields_free_string.

#ifndef HUDHUD_SHIELDS_H_
#define HUDHUD_SHIELDS_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct HudhudShields HudhudShields;

HudhudShields* hudhud_shields_load(const uint8_t* data, size_t len);
void hudhud_shields_free(HudhudShields* shields);

bool hudhud_shields_should_block(const HudhudShields* shields,
                               const char* url,
                               const char* source_url,
                               const char* request_type);

// {"hide_selectors": [...], "exceptions": [...], "generichide": bool}
char* hudhud_shields_page_resources(const HudhudShields* shields, const char* url);

// a JSON list of CSS selectors
char* hudhud_shields_hidden_selectors(const HudhudShields* shields,
                                    const char* classes_json,
                                    const char* ids_json,
                                    const char* exceptions_json);

void hudhud_shields_free_string(char* string);

#ifdef __cplusplus
}
#endif

#endif  // HUDHUD_SHIELDS_H_
