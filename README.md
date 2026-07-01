Hi there, this repo wont get updates for the client side anymore.

Take a look at the https://github.com/Asmod4n/mruby-url repo how to interact with websockets from now on.

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
===========
```ruby
client = WebSocket::Client.new("echo.websocket.org", 443, '/', ciphers: 'TLSv1.2')
client.send "hallo"
client.recv
client.close

```
