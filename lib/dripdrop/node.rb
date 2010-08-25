require 'rubygems'
require 'ffi-rzmq'
require 'em-synchrony'
require 'uri'
require 'dripdrop/message'
require 'dripdrop/handlers'

class DripDrop
  class Node
    attr_accessor :debug
    
    def initialize(opts={},&block)
      @handlers = {}
      @debug    = opts[:debug]
      @recipients_for = {}
      @handler_default_opts = {:debug => @debug}
      EM.synchrony do
        block.call(self)
      end
    end

    def zmq_subscribe(address,opts={},&block)
      h_opts = handler_opts_given(opts)
      
      handler = DripDrop::ZMQSubHandler.new(address,h_opts)
      handler.on_recv {|msg| block.call(msg)} if block
      
      handler
    end

    def zmq_publish(address,opts={},&block)
      DripDrop::ZMQPubHandler.new(address,handler_opts_given(opts))
    end
    
    def websocket(address,opts={},&block)
      wsh = DripDrop::WebSocketHandler.new(URI.parse(address),handler_opts_given(opts))
      wsh
    end

    def custom_handler(&block)
      joinable = block.call(self)
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
