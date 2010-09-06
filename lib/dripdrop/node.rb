require 'rubygems'
require 'ffi-rzmq'
require 'zmqmachine'
require 'eventmachine'
require 'uri'

require 'dripdrop/message'
require 'dripdrop/handlers/zeromq'
require 'dripdrop/handlers/websockets'

class DripDrop
  class Node
    attr_reader   :zm_reactor
    attr_accessor :debug
    
    def initialize(opts={},&block)
      @handlers = {}
      @debug    = opts[:debug]
      @recipients_for = {}
      @handler_default_opts = {:debug => @debug}
      @zm_reactor = nil
      
      EM.run do
        ZM::Reactor.new(:my_reactor).run do |zm_reactor|
          @zm_reactor = zm_reactor
          block.call(self)
        end
      end
    end
     
    def zmq_subscribe(address,opts={},&block)
      zm_addr = str_to_zm_address(address)
      h_opts  = handler_opts_given(opts)
      handler = DripDrop::ZMQSubHandler.new(zm_addr,@zm_reactor,h_opts)
      @zm_reactor.sub_socket(handler)
      handler
    end

    def zmq_publish(address,opts={})
      zm_addr = str_to_zm_address(address)
      h_opts  = handler_opts_given(opts)
      handler = DripDrop::ZMQPubHandler.new(zm_addr,@zm_reactor,h_opts)
      @zm_reactor.pub_socket(handler)
      handler
    end

    def zmq_pull(address,opts={},&block)
      zm_addr = str_to_zm_address(address)
      h_opts  = handler_opts_given(opts)
      handler = DripDrop::ZMQPullHandler.new(zm_addr,@zm_reactor,h_opts)
      @zm_reactor.pull_socket(handler)
      handler
    end

    def zmq_push(address,opts={})
      zm_addr = str_to_zm_address(address)
      h_opts  = handler_opts_given(opts)
      handler = DripDrop::ZMQPushHandler.new(zm_addr,@zm_reactor,h_opts)
      @zm_reactor.push_socket(handler)
      handler
    end
    
    def websocket(address,opts={},&block)
      uri     = URI.parse(address)
      h_opts  = handler_opts_given(opts)
      handler = DripDrop::WebSocketHandler.new(uri,h_opts)
      handler
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
    
    def str_to_zm_address(str)
      addr_uri = URI.parse(str)
      ZM::Address.new(addr_uri.host,addr_uri.port.to_i,addr_uri.scheme.to_sym)
    end
    
    def handler_opts_given(opts)
      @handler_default_opts.merge(opts)
    end
  end
end
