# mruby-websockets


Example

```ruby
client = WebSocket::Client.new(nil, "echo.websocket.org", 80, "/") do |msg|
  puts msg
end

client.send "hallo"

client.run
client.run
client.close
client.run
client.run
client.run
client.run

````
