require 'rubygems'
require 'ffi-rzmq'
require 'zmqmachine'
require 'eventmachine'
require 'uri'

require 'dripdrop/message'
require 'dripdrop/handlers/zeromq'
require 'dripdrop/handlers/websockets'
require 'dripdrop/handlers/http'

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
      @block = block
      @thread = nil
    end

    def start
      @thread = Thread.new do
        EM.run do
          ZM::Reactor.new(:my_reactor).run do |zm_reactor|
            @zm_reactor = zm_reactor
            self.instance_eval(&@block)
          end
        end
      end
    end

    def join
      if @thread
        @thread.join
      else
        raise "Can't join on a node that isn't yet started"
      end
    end

    #Blocking version of start, equivalent to +start+ then +join+
    def start!
      self.start
      self.join
    end

    def stop
      @zm_reactor.stop
      EM.stop
    end

    #TODO: All these need to be majorly DRYed up
     
    # Creates a ZMQ::SUB type socket. Can only receive messages via +on_recv+
    def zmq_subscribe(address,socket_ctype,opts={},&block)
      zm_addr = str_to_zm_address(address)
      h_opts  = handler_opts_given(opts)
      handler = DripDrop::ZMQSubHandler.new(zm_addr,@zm_reactor,socket_ctype,h_opts)
      @zm_reactor.sub_socket(handler)
      handler
    end

    # Creates a ZMQ::PUB type socket, can only send messages via +send_message+
    def zmq_publish(address,socket_ctype,opts={})
      zm_addr = str_to_zm_address(address)
      h_opts  = handler_opts_given(opts)
      handler = DripDrop::ZMQPubHandler.new(zm_addr,@zm_reactor,socket_ctype,h_opts)
      @zm_reactor.pub_socket(handler)
      handler
    end

    # Creates a ZMQ::PULL type socket. Can only receive messages via +on_recv+
    def zmq_pull(address,socket_ctype,opts={},&block)
      zm_addr = str_to_zm_address(address)
      h_opts  = handler_opts_given(opts)
      handler = DripDrop::ZMQPullHandler.new(zm_addr,@zm_reactor,socket_ctype,h_opts)
      @zm_reactor.pull_socket(handler)
      handler
    end

    # Creates a ZMQ::PUSH type socket, can only send messages via +send_message+
    def zmq_push(address,socket_ctype,opts={})
      zm_addr = str_to_zm_address(address)
      h_opts  = handler_opts_given(opts)
      handler = DripDrop::ZMQPushHandler.new(zm_addr,@zm_reactor,socket_ctype,h_opts)
      @zm_reactor.push_socket(handler)
      handler
    end
    
    # Creates a ZMQ::XREP type socket, both sends and receivesc XREP sockets are extremely
    # powerful, so their functionality is currently limited. XREP sockets in DripDrop can reply
    # to the original source of the message.
    #
    # Receiving with XREP sockets in DripDrop is different than other types of sockets, on_recv
    # passes 3 arguments to its callback, +identities+, +seq+, and +message+. Identities is the 
    # socket identity, seq is the sequence number of the message (all messages received at the socket
    # get a monotonically incrementing +seq+, and +message+ is the message itself.
    # 
    # To reply from an xrep handler, be sure to call send messages with the same +identities+ and +seq+
    # arguments that +on_recv+ had. So, send_message takes +identities+, +seq+, and +message+.
    def zmq_xrep(address,socket_ctype,opts={})
      zm_addr = str_to_zm_address(address)
      h_opts  = handler_opts_given(opts)
      handler = DripDrop::ZMQXRepHandler.new(zm_addr,@zm_reactor,socket_ctype,h_opts)
      @zm_reactor.xrep_socket(handler)
      handler
    end
 
    # See the documentation for +zmq_xrep+ for more info
    def zmq_xreq(address,socket_ctype,opts={})
      zm_addr = str_to_zm_address(address)
      h_opts  = handler_opts_given(opts)
      handler = DripDrop::ZMQXReqHandler.new(zm_addr,@zm_reactor,socket_ctype,h_opts)
      @zm_reactor.xreq_socket(handler)
      handler
    end
    
    def websocket(address,opts={},&block)
      uri     = URI.parse(address)
      h_opts  = handler_opts_given(opts)
      handler = DripDrop::WebSocketHandler.new(uri,h_opts)
      handler
    end
    
    def http_server(address,opts={},&block)
      uri     = URI.parse(address)
      h_opts  = handler_opts_given(opts)
      handler = DripDrop::HTTPServerHandler.new(uri, h_opts,&block)
      handler
    end
    
    def http_client(address,opts={})
      uri     = URI.parse(address)
      h_opts  = handler_opts_given(opts)
      handler = DripDrop::HTTPClientHandler.new(uri, h_opts)
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
