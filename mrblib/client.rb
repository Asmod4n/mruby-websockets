module WebSocket
  class WsConnection
    def initialize(host, port, path, *args)
      @host = host
      @port = port
      @path = path
      @socket = TCPSocket.new host, port
    end

    def recv(timeout)
      if @msgs.empty?
        if @client.want_read?
          @socket_pi.events = ZMQ::POLLIN
          pis = @poller.wait(timeout)
          if pis
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
        if @poller.wait(timeout)
          @client.send
        else
          break
        end
      end
    end

    def send(msg, opcode, timeout)
      if opcode
        @client.queue_msg(msg, opcode)
      else
        @client.queue_msg(msg)
      end
      @socket_pi.events = ZMQ::POLLOUT
      while @client.want_write?
        pis = @poller.wait(timeout)
        if pis
          @client.send
        else
          return pis
        end
      end
      self
    end

    def close(status_code, reason, timeout)
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
        if pis
          @client.send if @socket_pi.writable?
          @client.recv if @socket_pi.readable?
        else
          return pis
        end
      end
      @msgs.dup
    ensure
      @socket.close
      @msgs.clear
    end

    def setup
      http_handshake
      make_nonblock
      setup_ws
      setup_poller
    end

    private
    def http_handshake
      key = WebSocket.create_key
      @socket.write("GET #{@path} HTTP/1.1\r\nHost: #{@host}:#{@port}\r\nConnection: Upgrade\r\nUpgrade: WebSocket\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: #{key}\r\n\r\n")
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
    end

    def make_nonblock
      @socket._setnonblock(true)
    end

    def setup_ws
      @callbacks = Wslay::Event::Callbacks.new
      @callbacks.recv_callback {|buf, len| @socket.recv len}
      @callbacks.send_callback {|buf| @socket.write buf}
      @msgs = []
      @callbacks.on_msg_recv_callback {|msg| @msgs << msg}
      @client = Wslay::Event::Context::Client.new @callbacks
    end

    def setup_poller
      @poller = ZMQ::Poller.new
      @socket_pi = @poller.add(@socket)
    end
  end

  class WssConnection < WsConnection
    def initialize(host, port, path, *args)
      @host = host
      @port = port
      @path = path
      @tcp_socket = TCPSocket.new host, port
      @socket = Tls::Client.new(*args)
      @socket.connect_socket @tcp_socket.fileno, host
    end

    private
    def make_nonblock
      @tcp_socket._setnonblock(true)
    end

    def setup_poller
      @poller = ZMQ::Poller.new
      @socket_pi = @poller.add(@tcp_socket)
    end
  end

  class Client
    def initialize(proto, host, port, path, *args)
      case proto
      when :ws
        @connection = WsConnection.new(host, port, path, *args)
      when :wss
        @connection = WssConnection.new(host, port, path, *args)
      end
      @connection.setup
    end

    def recv(timeout = -1)
      @connection.recv(timeout)
    end

    def send(msg, opcode = nil, timeout = -1)
      if (ret = @connection.send(msg, opcode, timeout))
        self
      else
        ret
      end
    end

    alias :<< :send

    def close(status_code = :normal_closure, reason = nil, timeout = -1)
      @connection.close(status_code, reason, timeout)
    end
  end
end
