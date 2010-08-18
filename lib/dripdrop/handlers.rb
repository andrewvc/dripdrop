require 'eventmachine'
require 'em-websocket'
require 'json'

class DripDrop
  class ZMQSubHandler
    attr_reader :socket, :address, :collector, :recv_mode
    attr_accessor :context
    
    #Takes a zmqmachine reactor in sub mode's context, self, address, and a CollectorPublisher
    def initialize(address,opts={},&block)
      @address      = address
      @publisher    = opts[:publisher]
      @socket_ctype = opts[:socket_ctype]
      @debug        = opts[:debug]
      @recv_cbak    = block
    end
    
    def on_attach(socket)
      if @socket_ctype == :connect
        socket.connect(@address)
      else
        socket.bind(@address)
      end
      socket.subscribe ''
    end
    
    def on_readable(socket, messages)
      messages.each do |message|
        puts "ZMQSub recv" if @debug
        case @recv_mode
        when :parse
          message = DripDrop::Message.parse(message.copy_out_string)
        when :copy_str
          message = message.copy_out_string
        end
        @recv_cbak.call(message,self)
      end
    end
    
    def on_recv_str(&block)
      @recv_mode = :copy_str
      @recv_cbak = block
    end

    def on_recv(&block)
      @recv_mode = :parse
      @recv_cbak = block
    end

    def on_recv_raw(&block)
      @recv_mode = :raw
      @recv_cbak = block
    end
  end
  class ZMQPubHandler
    attr_reader :context, :socket, :address
  
    #Takes either as string or URI as an address
    def initialize(address,opts={})
      @address  = address
      @context  = ZMQ::Context.new(1)
      @raw      = opts[:raw]
      @socket   = @context.socket(ZMQ::PUB)
      @socket_ctype = opts[:socket_ctype]
      @debug        = opts[:debug]

      if @socket_ctype == :bind
        @socket.bind(@address.to_s)
      else
        @socket.connect(@address.to_s)
      end

    end
    
    #Sends a message along
    def send_message(message)
      puts "ZMQPub send_message" if @debug
      if    message.is_a?(ZMQ::Message)
        @socket.send(message)
      elsif message.is_a?(DripDrop::Message)
        @socket.send_string(message.encoded)
      else
        @socket.send_string(message.to_s)
      end
    end
  end
  class WebSocketHandler
    attr_reader :ws, :address
   
    def initialize(address,opts={},&block)
      @raw = false #Deal in strings or ZMQ::Message objects
      Thread.new do
        EventMachine.run do
          host, port = address.host, address.port.to_i
          @debug = opts[:debug] || false
          @onmessage_handler = block

          ws_conn = EventMachine::WebSocket::Connection
          EventMachine::start_server(host,port,ws_conn,:debug => @debug) do |ws|
            @ws = ws
            @ws.onopen do
              @onopen_handler.call(ws)
            end
            @ws.onmessage do |message|
              message = message.copy_out_string if @raw
              @onmessage_handler.call(message,ws)
            end
            @ws.onclose do
              @onclose_handler.call()
            end
          end
        end   
      end
    end
    
    def on_recv(&block)
      @raw = false
      @onmessage_handler = block
      self
    end

    def on_recv_raw(&block)
      @raw = true
      @onmessage_handler = block
      self
    end

    def on_open(&block)
      @onopen_handler = block
      self
    end
  
    def on_close(&block)
      @onclose_handler = block
      self
    end
  end
end
