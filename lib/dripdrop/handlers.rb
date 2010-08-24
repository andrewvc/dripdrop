require 'eventmachine'
require 'em-websocket'
require 'json'

class DripDrop
  class ZMQSubHandler
    attr_reader :socket, :address, :recv_mode, :thread
    attr_accessor :context
    
    #Takes a zmqmachine reactor in sub mode's context, self, address, and a CollectorPublisher
    def initialize(address,opts={},&block)
      @address      = address
      @publisher    = opts[:publisher]
      @socket_ctype = opts[:socket_ctype]
      @debug        = opts[:debug]
      @recv_cbak    = block
      @context      = ZMQ::Context.new(1)
      @socket       = @context.socket(ZMQ::SUB)
      @socket.setsockopt(ZMQ::SUBSCRIBE,'')
      
      if @socket_ctype == :bind
        @socket.bind(@address)
      else
        @socket.connect(@address)
      end
    end
    
    def on_recv_str(&block)
      on_readable(:copy_str, block)
      self
    end

    def on_recv(&block)
      on_readable(:parse, block)
      self
    end

    def on_recv_raw(&block)
      on_readable(:raw, block)
      self
    end
    
    def on_readable(mode, block)
      @thread = Thread.new do
        begin
          while message = @socket.recv
            EM::Deferrable.future(message) do |message|
                puts 'recvd'
                if mode == :parse
                  block.call(DripDrop::Message.parse(message))
                else
                  block.call(message)
                end
              end
            end
        rescue Exception => e
          puts e.inspect  
        end
      end
    end
    
    def join
      @thread.join
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
       
      if @socket_ctype == :connect
        @socket.connect(@address.to_s)
      else
        @socket.bind(@address.to_s)
      end

    end
    
    #Sends a message along
    def send_message(message)
      puts "ZMQPub send_message" if @debug
      if message.is_a?(DripDrop::Message)
        @socket.send(message.encoded)
      else
        @socket.send(message.to_s)
      end
    end
  end
  class WebSocketHandler
    attr_reader :ws, :address, :thread
   
    def initialize(address,opts={})
      @raw    = false #Deal in strings or ZMQ::Message objects
      @thread = Thread.new do
          host, port = address.host, address.port.to_i
          @debug = opts[:debug] || false

          ws_conn = EventMachine::WebSocket::Connection
          EventMachine::start_server(host,port,ws_conn,:debug => @debug) do |ws|
            @ws = ws
            @ws.onopen do
              @onopen_handler.call(ws) if @onopen_handler
            end
            @ws.onmessage do |message|
              unless @raw
                begin
                  parsed = JSON.parse(message)
                  message = DripDrop::Message.new(parsed['name'], :body => parsed['body'], :head => parsed['head'] || {})
                rescue StandardError => e
                  puts "Could not parse message: #{e.message}"
                end
              end
              @onmessage_handler.call(message,ws) if @onmessage_handler
            end
            @ws.onclose do
              @onclose_handler.call(@ws) if @onclose_handler
            end
            @ws.onerror do
              @onerror_handler.call(@ws) if @onerror_handler
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
    
    def on_error(&block)
      @onerror_handler = block
      self
    end
  end
end
