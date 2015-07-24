#ifndef MRUBY_WEBSOCKET_H
#define MRUBY_WEBSOCKET_H

#include <mruby.h>

#ifdef __cplusplus
extern "C" {
#endif

#define E_WEBSOCKET_ERROR mrb_class_get_under(mrb, mrb_module_get(mrb, "WebSocket"), "Error")

#ifdef __cplusplus
}
#endif

#endif
