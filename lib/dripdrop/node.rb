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
        @joinables      = [] #an array of proces to be executed as a join
        @recipients_for = {}
        @handler_default_opts = {:debug => @debug}
        @reactor = ZM::Reactor.new(:node)
        @reactor.run
        @joinables << lambda { reactor.join }
        block.call(self)
    end

    def join
      @joinables.each {|j| j.call}
    end

    def send_internal(dest,data)
      return false unless @recipients_for[dest]
      blocks = @recipients_for[dest].values
      return false unless blocks
      blocks.each do |block|
        block.call(data)
      end
    end

    def recv_internal(dest,identifier,&block)
      if @recipients_for[dest]
        @recipients_for[dest][identifier] =  block
      else
        @recipients_for[dest] = {identifier => block}
      end
    end

    def remove_recv_internal(dest,identifier)
      return false unless @recipients_for[dest]
      @recipients_for[dest].delete(identifier)
    end

    def zmq_subscribe(address,opts={},&block)
      zm_address = str_to_zm_address(address)
      h_opts = handler_opts_given(opts)
      
      handler = DripDrop::ZMQSubHandler.new(address,h_opts)
      handler.context = @reactor
      handler.on_recv {|msg| block.call(msg)} if block
      @reactor.sub_socket(handler)
      
      handler
    end

    def zmq_publish(address,opts={},&block)
      DripDrop::ZMQPubHandler.new(address,handler_opts_given(opts))
    end
    
    def websocket(address,opts={},&block)
      wsh = DripDrop::WebSocketHandler.new(URI.parse(address),handler_opts_given(opts))
      @joinables << lambda { wsh.thread.join }
      wsh
    end

    def custom_handler(&block)
      joinable = block.call(self)
      @joinables << lambda { joinable.join }
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
