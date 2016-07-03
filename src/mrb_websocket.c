#include "mruby/websocket.h"
#include "mrb_websocket.h"

#define WS_GUID "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

static mrb_value
mrb_websocket_create_accept(mrb_state *mrb, mrb_value self)
{
  char *client_key;
  mrb_int client_key_len;

  mrb_get_args(mrb, "s", &client_key, &client_key_len);

  if (client_key_len != 24)
    mrb_raise(mrb, E_WEBSOCKET_ERROR, "wrong client key len");

  uint8_t key_src[60];
  memcpy(key_src, client_key, 24);
  memcpy(key_src+24, WS_GUID, 36);

  uint8_t sha1buf[20];
  if (!SHA1((const unsigned char *) key_src, 60, sha1buf))
    mrb_raise(mrb, E_RUNTIME_ERROR, "SHA1 failed");

  mrb_value accept_key = mrb_str_new(mrb, NULL, 28);
  char *c = RSTRING_PTR(accept_key);
  base64_encodestate s;
  base64_init_encodestate(&s);
  c += base64_encode_block((const char *) sha1buf, 20, c, &s);
  base64_encode_blockend(c, &s);

  return accept_key;
}

void
mrb_mruby_websockets_gem_init(mrb_state* mrb) {
  struct RClass *websocket_mod;

  websocket_mod = mrb_define_module(mrb, "WebSocket");
  mrb_define_class_under(mrb, websocket_mod, "Error", E_RUNTIME_ERROR);
  mrb_define_module_function(mrb, websocket_mod, "create_accept", mrb_websocket_create_accept, MRB_ARGS_REQ(1));
}

void
mrb_mruby_websockets_gem_final(mrb_state* mrb) {
  /* finalizer */
}
