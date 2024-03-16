module WebSocket
  def self.create_key
    B64.encode(Sysrandom.buf(16)).chomp!
  end

  class Connection
    def initialize(host, port, path, *args)
      @host = host
      @port = port
      @path = path
      @tcp_socket = TCPSocket.new host, port
      @socket = Tls::Client.new(*args)
      @socket.connect_socket @tcp_socket.fileno, host
      setup()
    end

    def recv(timeout)
      if @msgs.empty?
        if @client.want_read?
          @socket_pi.events = Poll::In
          @client.recv if @poll.wait(timeout)
        end
      end
      @msgs.shift
    ensure
      @socket_pi.events = Poll::Out
      while @client.want_write?
        if @poll.wait(timeout)
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
      @socket_pi.events = Poll::Out
      while @client.want_write?
        if @poll.wait(timeout)
          @client.send
        else
          break
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
        @socket_pi.events |= Poll::In  if @client.want_read?
        @socket_pi.events |= Poll::Out if @client.want_write?
        if @poll.wait(timeout)
          @client.send if @socket_pi.writable?
          @client.recv if @socket_pi.readable?
        else
          break
        end
      end
      @msgs.dup
    ensure
      @msgs.clear
      @tcp_socket._setnonblock(false)
      @socket.close
      @tcp_socket.close
    end

    private
    def setup
      http_handshake
      make_nonblock
      setup_poller
      setup_ws
    rescue => e
      @tcp_socket._setnonblock(false)
      @socket.close
      @tcp_socket.close
      raise e
    end

    def http_handshake
      key = WebSocket.create_key
      @socket.write("GET #{@path} HTTP/1.1\r\nHost: #{@host}:#{@port}\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: #{key}\r\n\r\n")
      buf = @socket.read
      phr = Phr.new
      while true
        case phr.parse_response(buf)
        when Fixnum
          break
        when :incomplete
          buf << @socket.read
        when :parser_error
          raise Error, "HTTP Parser error"
        end
      end
      unless WebSocket.create_accept(key).securecmp(phr.headers.to_h.fetch('sec-websocket-accept'))
        raise Error, "Handshake failure"
      end
    end

    def make_nonblock
      @tcp_socket._setnonblock(true)
    end

    def setup_poller
      @poll = Poll.new
      @socket_pi = @poll.add(@tcp_socket)
    end

    def setup_ws
      @callbacks = Wslay::Event::Callbacks.new
      @callbacks.recv_callback {|buf, len| @socket.read_nonblock len}
      @callbacks.send_callback {|buf| @socket.write_nonblock buf}
      @msgs = []
      @callbacks.on_msg_recv_callback {|msg| @msgs << msg}
      @client = Wslay::Event::Context::Client.new @callbacks
    end
  end

  class Client
    def initialize(host, port, path, *args)
      @connection = Connection.new(host, port, path, *args)
    end

    def recv(timeout = -1)
      @connection.recv(timeout)
    end

    def send(msg, opcode = nil, timeout = -1)
      @connection.send(msg, opcode, timeout)
      self
    end

    alias :<< :send

    def close(status_code = :normal_closure, reason = nil, timeout = -1)
      @connection.close(status_code, reason, timeout)
    end
  end
end
