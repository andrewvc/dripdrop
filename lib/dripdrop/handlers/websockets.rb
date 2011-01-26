require 'em-websocket'
require 'json'

class DripDrop
  class WebSocketHandler < BaseHandler
    attr_reader :ws, :address, :thread
   
    def initialize(address,opts={})
      @raw    = false #Deal in strings or ZMQ::Message objects
      host, port = address.host, address.port.to_i
      @debug = opts[:debug] || false

      EventMachine::WebSocket.start(:host => host,:port => port,:debug => @debug) do |ws|
        #A WebSocketHandler:Connection gets passed to all callbacks 
        dd_conn = Connection.new(ws)
          
        ws.onopen { @onopen_handler.call(dd_conn) if @onopen_handler }
        ws.onclose { @onclose_handler.call(dd_conn) if @onclose_handler }
        ws.onerror {|reason| @onerror_handler.call(reason, dd_conn) if @onerror_handler }
        
        ws.onmessage do |message|
          if @onmessage_handler
            begin
              message = DripDrop::Message.decode_json(message) unless @raw
            rescue StandardError => e
              $stderr.write "Could not parse message: #{e.message}" if @debug
            end
             
            @onmessage_handler.call(message,dd_conn)
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
    attr_reader :ws, :signature, :handler
    
    def initialize(ws)
      @ws = ws
      @signature = @ws.signature
    end

    def send_message(message)
      @ws.send(dd_messagify(message).to_hash.to_json)
    end
  end
end
