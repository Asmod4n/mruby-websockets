#ifndef MRUBY_WEBSOCKET_H
#define MRUBY_WEBSOCKET_H

#include <mruby.h>

MRB_BEGIN_DECL

#define E_WEBSOCKET_ERROR mrb_class_get_under(mrb, mrb_module_get(mrb, "WebSocket"), "Error")

MRB_END_DECL

#endif
