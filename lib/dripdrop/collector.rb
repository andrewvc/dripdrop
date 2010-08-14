require 'rubygems'
require 'ffi-rzmq'
require 'zmqmachine'
require 'uri'

class DripDrop
  class CollectorPub
    attr_reader :context, :socket, :address
    
    def initialize(address)
      @address = address
      @context = ZMQ::Context.new(1)
      @socket  = @context.socket(ZMQ::PUB)
      @socket.bind(@address.to_s)
    end
    
    def send_message(message)
      @socket.send(message)
    end
  end
  class CollectorSub
    attr_reader :context, :socket, :address
    
    def initialize(context,address, publisher)
      @context = context
      @address = address
      @publisher = publisher
    end
    
    def on_attach(socket)
      socket.bind(@address)
      socket.subscribe ''
    end
    
    def on_readable(socket, messages)
      messages.each {|message| @publisher.send_message(message) }
    end
  end
  
  class Collector
    attr_reader :sub_reactor, :sub_addr, :pub_addr
    def initialize(sub_addr='tcp://127.0.0.1:2900',pub_addr='tcp://127.0.0.1:2901')
      @pub_addr    = URI.parse(pub_addr)
      sub_addr_uri = URI.parse(sub_addr)
      @sub_addr    = ZM::Address.new(sub_addr_uri.host, sub_addr_uri.port.to_i, sub_addr_uri.scheme.to_sym)
      @sub_reactor = ZM::Reactor.new(:sub_reactor)
      
      @publisher = CollectorPub.new(@pub_addr)
    end

    def run
      @sub_reactor.run do |context|
        context.sub_socket CollectorSub.new(context, @sub_addr,@publisher)
      end
      @sub_reactor.join
    end
  end
end
