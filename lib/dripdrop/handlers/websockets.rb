require 'em-websocket'

class DripDrop
  class WebSocketHandler < BaseHandler
    class SocketError < StandardError; attr_accessor :reason, :connection end
    
    attr_reader :ws, :address, :thread
   
    def initialize(address,opts={})
      @raw    = false #Deal in strings or ZMQ::Message objects
      host, port = address.host, address.port.to_i
      @debug = opts[:debug] || false

      EventMachine::WebSocket.start(:host => host,:port => port,:debug => @debug) do |ws|
        #A WebSocketHandler:Connection gets passed to all callbacks 
        dd_conn = Connection.new(ws)
          
        ws.onopen  { @onopen_handler.call(dd_conn) if @onopen_handler }
        ws.onclose { @onclose_handler.call(dd_conn) if @onclose_handler }
        ws.onerror {|reason|
          e = SocketError.new
          e.reason     = reason
          e.connection = dd_conn
          handle_error(e)
        }
        
        ws.onmessage do |message|
          if @onmessage_handler
            begin
              message = DripDrop::Message.decode(message) unless @raw
              @onmessage_handler.call(message,dd_conn)
            rescue StandardError => e
              handle_error(e)
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
  
  class WebSocketHandler::Connection < BaseHandler
    attr_reader :ws, :signature, :handler
    
    def initialize(ws)
      @ws = ws
      @signature = @ws.signature
    end

    def send_message(message)
      encoded_message = dd_messagify(message).encoded
      @ws.send(encoded_message)
    end
  end
end
