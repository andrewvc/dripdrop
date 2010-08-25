require 'rubygems'
require 'ffi-rzmq'
require 'eventmachine'
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
      @joinables = [] #Threads to join on if we aren't using EM      

      if opts[:no_em]
        block.call(self)
        @joinables.each {|j| j.call}
      else
        EM.run do
          block.call(self)
        end
      end
    end

    def zmq_subscribe(address,opts={},&block)
      h_opts = handler_opts_given(opts)
      
      handler = DripDrop::ZMQSubHandler.new(address,h_opts)
      handler.on_recv {|msg| block.call(msg)} if block
      @joinables << lambda {handler.join}
      
      handler
    end

    def zmq_publish(address,opts={},&block)
      DripDrop::ZMQPubHandler.new(address,handler_opts_given(opts))
    end
    
    def websocket(address,opts={},&block)
      wsh = DripDrop::WebSocketHandler.new(URI.parse(address),handler_opts_given(opts))
      wsh
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

    private
    
    def handler_opts_given(opts)
      @handler_default_opts.merge(opts)
    end
  end
end
