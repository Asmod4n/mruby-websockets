module WebSocket
  class Client
    def initialize(proto, host, port, path, options = {})
      case proto
      when :ws
        @socket = TCPSocket.new host, port
      when :wss
        raise Error, "wss not yet supported"
      end
      key = WebSocket.create_key
      @socket.write("GET #{path} HTTP/1.1\r\nHost: #{host}:#{port}\r\nConnection: Upgrade\r\nUpgrade: WebSocket\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: #{key}\r\n\r\n")
      buf = @socket.recv 16384
      phr = Phr.new
      loop do
        ret = phr.parse_response(buf)
        case ret
        when Fixnum
          break
        when :incomplete
          buf << @socket.recv(16384)
        when :parser_error
          @socket.close
          raise Error, "HTTP Parser error"
        end
      end
      headers = phr.headers.to_h
      unless Sodium.memcmp(WebSocket.create_accept(key), headers['sec-websocket-accept'])
        @socket.close
        raise Error, "Handshake failure"
      end
      @socket._setnonblock(true)
      @callbacks = Wslay::Event::Callbacks.new
      @callbacks.recv_callback {|buf, len| @socket.recv len, Socket::MSG_DONTWAIT}
      @callbacks.send_callback {|buf| @socket.send buf, Socket::MSG_DONTWAIT}
      @msgs = []
      @callbacks.on_msg_recv_callback {|msg| @msgs << msg}
      @client = Wslay::Event::Context::Client.new @callbacks
      @poller = ZMQ::Poller.new
      @socket_pi = @poller.add(@socket)
    end

    def recv(timeout = -1)
      if @msgs.empty?
        if @client.want_read?
          @socket_pi.events = ZMQ::POLLIN
          pis = @poller.wait(timeout)
          if pis.is_a? Array
            @client.recv
          else
            return pis
          end
        end
      end
      @msgs.shift
    ensure
      @socket_pi.events = ZMQ::POLLOUT
      while @client.want_write?
        pis = @poller.wait(timeout)
        if pis.is_a? Array
          @client.send
        else
          break
        end
      end
    end

    def send(msg, opcode = :text_frame, timeout = -1)
      @client.queue_msg(opcode, msg)
      @socket_pi.events = ZMQ::POLLOUT
      while @client.want_write?
        pis = @poller.wait(timeout)
        if pis.is_a? Array
          @client.send
        else
          return pis
        end
      end
      self
    end

    alias :<< :send

    def close(status_code = :normal_closure, reason = nil, timeout = -1)
      if reason
        @client.queue_close(status_code, reason)
      else
        @client.queue_close(status_code)
      end
      while @client.want_write?||@client.want_read?
        @socket_pi.events = 0
        @socket_pi.events |= ZMQ::POLLIN  if @client.want_read?
        @socket_pi.events |= ZMQ::POLLOUT if @client.want_write?
        pis = @poller.wait(timeout)
        if pis.is_a?(Array)
          @client.send if @socket_pi.writable?
          @client.recv if @socket_pi.readable?
        else
          return pis
        end
      end
      @msgs.dup
    ensure
      @socket.close unless @socket.closed?
      @msgs.clear
    end
  end
end
