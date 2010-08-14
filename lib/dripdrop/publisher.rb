require 'rubygems'
require 'em-synchrony'
require 'em-websocket'
require 'ffi-rzmq'
require 'zmqmachine'
require 'uri'
require 'json'
require 'dripdrop/collector'

class DripDrop
  class PublisherCollector < Collector
    def websockets
      @websockets ||= []
    end
    
    def add_websocket(ws)
      websockets << ws
      ws.send 'socket added'
    end

    def rem_websocket(ws)
      websockets.delete(ws)
    end
    
    def on_recv(message)
      json = message.to_hash.to_json
      websockets.each {|ws| ws.send(json)}
    end
  end

  class Publisher
    attr_reader :sub_address, :sub_collector, :ws_address
    def initialize(sub_address='tcp://127.0.0.1:2901',ws_address='ws://127.0.0.1:2902')
      @sub_address   = URI.parse(sub_address)
      @ws_address    = URI.parse(ws_address)
      @sub_collector = PublisherCollector.new('tcp://127.0.0.1:2901')
    end

    def run
      @sub_collector.run
      EventMachine.synchrony do
        host, port =  @ws_address.host, @ws_address.port.to_i
        EventMachine::WebSocket.start(:host => host, :port => port, :debug => true) do |ws|
          ws.onopen do
            ws.send("WS Connected")
            @sub_collector.add_websocket(ws)
          end
          ws.onclose do
            @sub_collector.rem_websocket(ws)
          end
        end
      end   
    end
  end
end
