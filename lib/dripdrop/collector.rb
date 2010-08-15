require 'ffi-rzmq'
require 'zmqmachine'
require 'uri'
require 'dripdrop/message'

class DripDrop
  #Publishes the ZMQ messages. This is not evented as zmqmachine seems
  #to max out the CPU on ZMQ::PUB sockets
  class CollectorPub
    attr_reader :context, :socket, :address
    
    #Takes either as string or URI as an address
    def initialize(address)
      @address = address
      @context = ZMQ::Context.new(1)
      @socket  = @context.socket(ZMQ::PUB)
      @socket.bind(@address.to_s)
    end
    
    #Sends an already encoded DripDrop::Message
    def send_message(message)
      @socket.send(message)
    end
  end
   
  #Listens on a zmqmachine sub_socket.
  class CollectorSub
    attr_reader :context, :socket, :address, :collector
    
    #Takes a zmqmachine reactor in sub mode's context, self, address, and a CollectorPublisher
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

  #Collector is meant to be subclassed. It's used to provide basic pub/sub functionality.
  #Subclasses should provide +on_recv+, which gets called on receipt of a message.
  #If pub_addr is specified +publish+ can be called, which sends a message to the pub socket.
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

    #Run the collector. Returns the reactor, so if this is the only thing in your script, be sure to call +join+ on the reactor.
    def run
      puts "Run"
      @sub_reactor.run do |context|
        context.sub_socket CollectorSub.new(context,self,@sub_addr,@publisher)
      end
      @sub_reactor
    end

    #If pub_addr was specified when the collector was initialized, messages can be broadcast using this.
    def publish(message)
      @publisher.send_string(message.encoded)
    end
     
    #Intended to be overriden by a subclass.
    #Receives an encoded DripDrop::Message
    def on_recv(message); end
  end
end
