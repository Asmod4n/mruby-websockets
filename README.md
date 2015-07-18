# mruby-websockets


Example

```ruby
client = WebSocket::Client.new(:ws, "echo.websocket.org", 80, "/")
client.send "hallo"
client.recv
client.close

````
