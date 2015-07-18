module WebSocket
  class Client
    def initialize(proto, host, port, path, &block)
      raise  ArgumentError, "no block given" unless block_given?
      @socket = TCPSocket.new host, port
      key = WebSocket.create_key
      @socket.write("GET #{path} HTTP/1.1\r\nHost: #{host}:#{port}\r\nConnection: Upgrade\r\nUpgrade: WebSocket\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: #{key}\r\n\r\n")
      buf = @socket.recv 16384
      phr = Phr.new
      ret = nil
      loop do
        ret = phr.parse_response(buf)
        case ret
        when Fixnum
          break
        when :incomplete
          buf << @socket.recv(16384)
        when :parser_error
          @socket.close
          return ret
        end
      end
      headers = phr.headers.to_h
      if headers['sec-websocket-accept'] != WebSocket.create_accept(key)
        @socket.close
        return :handshake_failed
      end
      @socket._setnonblock(true)
      @callbacks = Wslay::Event::Callbacks.new
      @callbacks.recv_callback do |len|
        begin
          @socket.recv len, Socket::MSG_DONTWAIT
        rescue Errno::EAGAIN, Errno::EWOULDBLOCK
          nil
        rescue => e
          raise e
        end
      end
      @callbacks.send_callback do |buf|
        begin
          @socket.send buf, Socket::MSG_DONTWAIT
        rescue Errno::EAGAIN, Errno::EWOULDBLOCK
          nil
        rescue => e
          raise e
        end
      end
      @callbacks.genmask_callback do |buf, len|
        RandomBytes.buf buf, len
      end
      @callbacks.on_msg_recv_callback(&block)
      @client = Wslay::Event::Context::Client.new @callbacks
      @reactor = CZMQ::Reactor.new
      @socket_pi = @reactor.poller(@socket, ZMQ::POLLIN|ZMQ::POLLOUT) do |socket_pi|
        if socket_pi.readable?
          @client.recv
        end
        if socket_pi.writable?
          @client.send
        end
      end
    end

    def run(mode = :once)
      if @client.want_read? ||@client.want_write?
        case mode
        when :once
          @reactor.run_once
        when :blocking
          @reactor.run
        when :nowait
          @reactor.run_nowait
        else
          fail "you broke it"
        end
        @socket_pi.events = 0
        @socket_pi.events |= ZMQ::POLLIN if @client.want_read?
        @socket_pi.events |= ZMQ::POLLOUT if @client.want_write?
      else
        @reactor.poller_end(@socket)
        @socket.close unless @socket.closed?
        return :closed
      end
      self
    end

    def send(msg, opcode = :text_frame)
      @client.queue_msg(opcode, msg)
    end

    def close(status_code = :normal_closure, reason = nil)
      if reason
        @client.queue_close(status_code, reason)
      else
        @client.queue_close(status_code)
      end
    end
  end
end
