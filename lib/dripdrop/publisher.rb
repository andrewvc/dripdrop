require 'rubygems'
require 'em-synchrony'
require 'em-websocket'
require 'ffi-rzmq'
require 'zmqmachine'
require 'uri'
require 'json'

class PublisherSub
  attr_reader :messages
  
  def initialize(context,address,websocket)
    @address   = address
    @context   = context
    @messages  = []
    @websocket = websocket
  end
  
  def on_attach(socket)
    @websocket.send("ZMQ Attached")
    socket.subscribe ''
    address = ZM::Address.new @address.host, @address.port.to_i, @address.scheme.to_sym
    rc = socket.connect(address)
  end

  def on_readable(socket,messages)
    @websocket.send messages.map {|m| DripDrop::Message.parse(m.copy_out_string).body}
  end
end

class Publisher
  attr_reader :sub_address,:ws_address, :ws, :sub_reactor
  def initialize(sub_address='tcp://127.0.0.1:2901',ws_address='ws://127.0.0.1:2902')
    @sub_address  = URI.parse(sub_address)
    @ws_address   = URI.parse(ws_address)
    @sub_reactor  = nil
    @ws           = nil #websocket
  end

  def run
    EventMachine.synchrony do
      EventMachine::WebSocket.start(:host => @ws_address.host, :port => @ws_address.port.to_i, :debug => true) do |ws|
        @ws = ws
        @ws.onopen do
          @ws.send("WS Connected")
          @sub_reactor = ZM::Reactor.new(:publisher)
          @sub_reactor.run do |context|
            zh = PublisherSub.new(context,@sub_address,@ws)
            context.sub_socket zh
          end
        end
      end
    end   
  end
end
