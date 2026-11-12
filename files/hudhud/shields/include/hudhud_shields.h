// Buna Browser's Shields engine (src/lib.rs, which documents each call).
// Strings are NUL-terminated UTF-8; lists are JSON.  Strings returned by
// these functions are freed with buna_shields_free_string.

#ifndef BUNA_SHIELDS_H_
#define BUNA_SHIELDS_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct BunaShields BunaShields;

BunaShields* buna_shields_load(const uint8_t* data, size_t len);
void buna_shields_free(BunaShields* shields);

bool buna_shields_should_block(const BunaShields* shields,
                               const char* url,
                               const char* source_url,
                               const char* request_type);

// {"hide_selectors": [...], "exceptions": [...], "generichide": bool}
char* buna_shields_page_resources(const BunaShields* shields, const char* url);

// a JSON list of CSS selectors
char* buna_shields_hidden_selectors(const BunaShields* shields,
                                    const char* classes_json,
                                    const char* ids_json,
                                    const char* exceptions_json);

void buna_shields_free_string(char* string);

#ifdef __cplusplus
}
#endif

#endif  // BUNA_SHIELDS_H_
