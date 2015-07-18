﻿#include <mruby.h>
#include <string.h>
#include <openssl/sha.h>
#include <mruby/string.h>
#include <b64/cencode.h>
#include <sodium.h>

#define WS_GUID "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

static mrb_value
mrb_websocket_create_accept(mrb_state *mrb, mrb_value self)
{
  char *client_key;
  mrb_int client_key_len;

  mrb_get_args(mrb, "s", &client_key, &client_key_len);

  if (client_key_len != 24)
    return mrb_symbol_value(mrb_intern_lit(mrb, "wrong_client_key_len"));

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

static mrb_value
mrb_websocket_create_key(mrb_state *mrb, mrb_value self)
{
  unsigned char random[16];
  randombytes_buf(random, 16);

  mrb_value key = mrb_str_new(mrb, NULL, 24);
  char *c = RSTRING_PTR(key);
  base64_encodestate s;
  base64_init_encodestate(&s);
  c += base64_encode_block((const char *) random, 16, c, &s);
  base64_encode_blockend(c, &s);

  return key;
}

void
mrb_mruby_websockets_gem_init(mrb_state* mrb) {
  struct RClass *websocket_mod;

  websocket_mod = mrb_define_module(mrb, "WebSocket");
  mrb_define_module_function(mrb, websocket_mod, "create_accept", mrb_websocket_create_accept, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, websocket_mod, "create_key", mrb_websocket_create_key, MRB_ARGS_NONE());
}

void
mrb_mruby_websockets_gem_final(mrb_state* mrb) {
  /* finalizer */
}