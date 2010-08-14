require 'ffi-rzmq'
require 'zmqmachine'
require 'uri'
require 'dripdrop/message'

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
    attr_reader :context, :socket, :address, :collector
    
    def initialize(context, collector, address, publisher=nil)
      @context   = context
      @collector = collector
      @address   = address
      @publisher = publisher
    end
    
    def on_attach(socket)
      socket.connect(@address)
      socket.subscribe ''
    end
    
    def on_readable(socket, messages)
      messages.each do |message|
        @collector.on_recv(DripDrop::Message.parse(message.copy_out_string))
      end
    end
  end
  
  class Collector
    attr_reader :sub_reactor, :sub_addr, :pub_addr
    def initialize(sub_addr='tcp://127.0.0.1:2900',pub_addr=nil)
      sub_addr_uri = URI.parse(sub_addr)
      host, port   = sub_addr_uri.host, sub_addr_uri.port.to_i
      scheme       = sub_addr_uri.scheme.to_sym
      @sub_addr    = ZM::Address.new(host, port, scheme)
      @sub_reactor = ZM::Reactor.new(:sub_reactor)
      
      if @pub_addr
        @pub_addr  = URI.parse(pub_addr)
        @publisher = CollectorPub.new(@pub_addr)
      end
    end

    def run
      puts "Run"
      @sub_reactor.run do |context|
        context.sub_socket CollectorSub.new(context,self,@sub_addr,@publisher)
      end
      @sub_reactor
    end

    def publish(message)
      @publisher.send_string(message.encoded)
    end
     
    def on_recv(message); end
  end
end
