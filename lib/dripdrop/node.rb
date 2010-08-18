require 'rubygems'
require 'ffi-rzmq'
require 'zmqmachine'
require 'uri'
require 'dripdrop/message'
require 'dripdrop/handlers'

class DripDrop
  class Node
    attr_accessor :debug
    
    def initialize(opts={},&block)
      @handlers = {}
      @debug    = opts[:debug]
      @handler_default_opts = {:debug => @debug}
      @joinables = [] #an array of proces to be executed as a join
      puts "Initialized with opts #{@handler_default_opts.inspect}" if @debug
      block.call(self)
    end

    def join
      @joinables.each {|j| j.call}
    end

    def zmq_subscribe(address,opts={},&block)
      puts "zmq_address" if @debug
      zm_address = str_to_zm_address(address)
      h_opts = handler_opts_given(opts)
      
      reactor = ZM::Reactor.new(:sub_reactor)
      handler = DripDrop::ZMQSubHandler.new(address,h_opts)
      reactor.run do |context|
        puts "CONTEXT RUNNIN"
        handler.context = context
        handler.on_recv(block) if block
        context.sub_socket(handler)
        puts "INIT"
      end
      @joinables << lambda { reactor.join }
      handler
    end
    
    def zmq_publish(address,opts={},&block)
      puts "zmq_publish: #{address.inspect}" if @debug
      DripDrop::ZMQPubHandler.new(address,handler_opts_given(opts))
    end
    
    def websocket(address,opts={},&block)
      puts "websocket: #{address.inspect}" if @debug
      wsh = DripDrop::WebSocketHandler.new(URI.parse(address),handler_opts_given(opts))
      @joinables << wsh
      wsh
    end

    private
    
    def str_to_zm_address(str)
      addr_uri = URI.parse(str)
      ZM::Address.new(addr_uri.host,addr_uri.port.to_i,addr_uri.scheme.to_sym)
    end
    
    def handler_opts_given(opts)
      @handler_default_opts.merge(opts)
    end
  end
end
