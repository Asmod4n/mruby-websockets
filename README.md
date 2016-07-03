# mruby-websockets

You need to have libressl installed, on macOS this can be easily done with homebrew.
Then add
```ruby
  conf.gem mgem: 'mruby-websockets' do |g|
    g.cc.include_paths << '/usr/local/opt/libressl/include'
    g.linker.library_paths << '/usr/local/opt/libressl/lib'
  end
```
to your build_config.rb

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
client = WebSocket::Client.new(:wss, "echo.websocket.org", 443, '/', ciphers: 'TLSv1.2') # needed for amazon web services
client.send "hallo"
client.recv
client.close

```
