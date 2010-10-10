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

    # Starts the reactors and runs the block passed to initialize.
    # This is non-blocking.
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

    # If the reactor has started, this blocks until the thread 
    # running the reactor joins. This should block forever
    # unless +stop+ is called.
    def join
      if @thread
        @thread.join
      else
        raise "Can't join on a node that isn't yet started"
      end
    end

    # Blocking version of start, equivalent to +start+ then +join+
    def start!
      self.start
      self.join
    end

    # Stops the reactors. If you were blocked on #join, that will unblock.
    def stop
      @zm_reactor.stop
      EM.stop
    end

    # Creates a ZMQ::SUB type socket. Can only receive messages via +on_recv+
    def zmq_subscribe(address,socket_ctype,opts={},&block)
      zmq_handler(DripDrop::ZMQSubHandler,:sub_socket,address,socket_ctype,opts={})
    end

    # Creates a ZMQ::PUB type socket, can only send messages via +send_message+
    def zmq_publish(address,socket_ctype,opts={})
      zmq_handler(DripDrop::ZMQPubHandler,:pub_socket,address,socket_ctype,opts={})
    end

    # Creates a ZMQ::PULL type socket. Can only receive messages via +on_recv+
    def zmq_pull(address,socket_ctype,opts={},&block)
      zmq_handler(DripDrop::ZMQPullHandler,:pull_socket,address,socket_ctype,opts={})
    end

    # Creates a ZMQ::PUSH type socket, can only send messages via +send_message+
    def zmq_push(address,socket_ctype,opts={})
      zmq_handler(DripDrop::ZMQPushHandler,:push_socket,address,socket_ctype,opts={})
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
      zmq_handler(DripDrop::ZMQXRepHandler,:xrep_socket,address,socket_ctype,opts={})
    end
 
    # See the documentation for +zmq_xrep+ for more info
    def zmq_xreq(address,socket_ctype,opts={})
      zmq_handler(DripDrop::ZMQXReqHandler,:xreq_socket,address,socket_ctype,opts={})
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

    # An inprocess pub/sub queue that works similarly to EM::Channel, 
    # but has manually specified identifiers for subscribers letting you
    # more easily delete subscribers without crazy id tracking.
    #  
    # This is useful for situations where you want to broadcast messages across your app,
    # but need a way to properly delete listeners.
    # 
    # +dest+ is the name of the pub/sub channel.
    # +data+ is any type of ruby var you'd like to send.
    def send_internal(dest,data)
      return false unless @recipients_for[dest]
      blocks = @recipients_for[dest].values
      return false unless blocks
      blocks.each do |block|
        block.call(data)
      end
    end

    # Defines a subscriber to the channel +dest+, to receive messages from +send_internal+.
    # +identifier+ is a unique identifier for this receiver.
    # The identifier can be used by +remove_recv_internal+ 
    def recv_internal(dest,identifier,&block)
      if @recipients_for[dest]
        @recipients_for[dest][identifier] =  block
      else
        @recipients_for[dest] = {identifier => block}
      end
    end

    # Deletes a subscriber to the channel +dest+ previously identified by a
    # reciever created with +recv_internal+
    def remove_recv_internal(dest,identifier)
      return false unless @recipients_for[dest]
      @recipients_for[dest].delete(identifier)
    end

    private
    
    def zmq_handler(klass, zm_sock_type, address, socket_ctype, opts={})
      addr_uri = URI.parse(address)
      zm_addr  = ZM::Address.new(addr_uri.host,addr_uri.port.to_i,addr_uri.scheme.to_sym)
      h_opts   = handler_opts_given(opts)
      handler  = klass.new(zm_addr,@zm_reactor,socket_ctype,h_opts)
      @zm_reactor.send(zm_sock_type,handler)
      handler
    end   
    
    def handler_opts_given(opts)
      @handler_default_opts.merge(opts)
    end
  end
end
