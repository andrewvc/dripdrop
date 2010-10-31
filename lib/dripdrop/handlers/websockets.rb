require 'em-websocket'
require 'json'

class DripDrop
  class WebSocketHandler < BaseHandler
    attr_reader :ws, :address, :thread
   
    def initialize(address,opts={})
      @raw    = false #Deal in strings or ZMQ::Message objects
      @thread = Thread.new do
          host, port = address.host, address.port.to_i
          @debug = opts[:debug] || false

          ws_conn = EventMachine::WebSocket::Connection
          EventMachine::start_server(host,port,ws_conn,:debug => @debug) do |ws|
            @ws = ws
            dd_conn = Connection.new(@ws)
            @ws.onopen do
              @onopen_handler.call(dd_conn) if @onopen_handler
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
              @onmessage_handler.call(message,dd_conn) if @onmessage_handler
            end
            @ws.onclose do
              @onclose_handler.call(dd_conn) if @onclose_handler
            end
            @ws.onerror do
              @onerror_handler.call(dd_conn) if @onerror_handler
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
  
  class WebSocketHandler::Connection < BaseHandler
    attr_reader :ws, :signature
    
    def initialize(ws)
      @ws = ws     
      @signature = @ws.signature
    end

    def send_message(message)
      @ws.send(dd_messagify(message).to_hash.to_json)
    end
  end
   
end
