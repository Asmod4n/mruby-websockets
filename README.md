# mruby-websockets


Example
=======
```ruby
client = WebSocket::Client.new(:ws, "echo.websocket.org", 80, "/")
client.send "hallo"
client.recv
client.close

````

wss Example
===========
```ruby
client = WebSocket::Client.new(:wss, "echo.websocket.org", 443, '/', ciphers: 'TLSv1.2' # needed for amazon web services)
client.send "hallo"
client.recv
client.close

```
