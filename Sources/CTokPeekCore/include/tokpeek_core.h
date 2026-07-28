#ifndef TOKPEEK_CORE_H
#define TOKPEEK_CORE_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

char *tokpeek_graph_report(const char *request_json);
void tokpeek_string_free(char *value);

#ifdef __cplusplus
}
#endif

#endif
