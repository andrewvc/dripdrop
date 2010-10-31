require 'rubygems'
require 'ffi-rzmq'
require 'zmqmachine'
require 'eventmachine'
require 'uri'

require 'dripdrop/message'
require 'dripdrop/node/nodelet'
require 'dripdrop/handlers/base'
require 'dripdrop/handlers/zeromq'
require 'dripdrop/handlers/websockets'
require 'dripdrop/handlers/http'

class DripDrop
  class Node
    attr_reader   :zm_reactor, :routing
    attr_accessor :debug
    
    def initialize(opts={},&block)
      @zm_reactor = nil # The instance of the zmq_machine reactor
      @block      = block
      @thread     = nil # Thread containing the reactors
      @routing    = {}  # Routing table
      @debug      = opts[:debug]
      @recipients_for       = {}
      @handler_default_opts = {:debug => @debug}
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

    # Defines a new route. Routes are the recommended way to instantiate
    # handlers. For example:
    #
    #    route :stats_pub, :zmq_publish, 'tcp://127.0.0.1:2200', :bind
    #    route :stats_sub, :zmq_subscribe, stats_pub.address, :connect
    #
    # Will make the following methods available within the reactor block:
    #    stats_pub  # A regular zmq_publish handler
    #    :stats_sub # A regular zmq_subscribe handler
    #
    # See the docs for +routes_for+ for more info in grouping routes for
    # nodelets and maintaining sanity in larger apps
    def route(name,handler_type,*handler_args)
      # If we're in a route_for block, prepend appropriately
      full_name = @route_prepend ? "#{@route_prepend}_#{name}".to_sym : name
      
      handler = self.send(handler_type, *handler_args)
      @routing[full_name] = handler
      
      # Define the route name as a singleton method
      (class << self; self; end).class_eval do
        define_method(full_name) { handler }
      end
      
      handler
    end

    # Defines a group of +route+s, to be used as the interface for a +nodelet+
    # later on.
    # 
    # All routes defined with the +route_for+ block will be prepended with the
    # +nodelet_name+ and an underscore. So, the following routes:
    # 
    #    routes_for :forwarder do
    #      route :input,  :zmq_subscribe, 'tcp://127.0.0.1:2200', :bind
    #      route :output, :zmq_publish,   f.in.address, :connect
    #    end
    # 
    # Will yield the routes: +forwarder_input+ and +forwarder_output+ globally.
    # Within the block scope of the +forwarder+ nodelet however, the routes are additionally
    # available with their own short names. See the +nodelet+ method for details.
    def routes_for(nodelet_name,&block)
      @route_prepend = nodelet_name #This feels ugly. Blech.
      block.call
      @route_prepend = nil
    end

    # Nodelets are a way of segmenting a DripDrop::Node. This can be used
    # for both organization and deployment. One might want the production
    # deployment of an app to be broken across multiple servers or processes
    # for instance. Additionally, by combining nodelets with +routes_for+
    # managing routes becomes a little easier.
    #
    # Nodelets can be used thusly:
    #    routes_for :heartbeat do
    #      route :ticker, :zmq_publish, 'tcp://127.0.0.1', :bind
    #    end
    #
    #    nodelet :heartbeat do
    #      zm_reactor.periodical_timer(500) do
    #      ticker.send_message(:name => 'tick')
    #    end
    def nodelet(name,&block)
      nlet_obj = Nodelet.new(name,routing)
      block.call(nlet_obj)
    end
    
    # Creates a ZMQ::SUB type socket. Can only receive messages via +on_recv+.
    # zmq_subscribe sockets have a +topic_filter+ option, which restricts which
    # messages they can receive. It takes a regexp as an option.
    def zmq_subscribe(address,socket_ctype,opts={},&block)
      zmq_handler(DripDrop::ZMQSubHandler,:sub_socket,address,socket_ctype,opts)
    end

    # Creates a ZMQ::PUB type socket, can only send messages via +send_message+
    def zmq_publish(address,socket_ctype,opts={})
      zmq_handler(DripDrop::ZMQPubHandler,:pub_socket,address,socket_ctype,opts)
    end

    # Creates a ZMQ::PULL type socket. Can only receive messages via +on_recv+
    def zmq_pull(address,socket_ctype,opts={},&block)
      zmq_handler(DripDrop::ZMQPullHandler,:pull_socket,address,socket_ctype,opts)
    end

    # Creates a ZMQ::PUSH type socket, can only send messages via +send_message+
    def zmq_push(address,socket_ctype,opts={})
      zmq_handler(DripDrop::ZMQPushHandler,:push_socket,address,socket_ctype,opts)
    end

    # Creates a ZMQ::XREP type socket, both sends and receivesc XREP sockets are extremely
    # powerful, so their functionality is currently limited. XREP sockets in DripDrop can reply
    # to the original source of the message.
    #
    # Receiving with XREP sockets in DripDrop is different than other types of sockets, on_recv
    # passes 3 arguments to its callback, +message+, +identities+, +seq+. Identities is the 
    # socket identity, seq is the sequence number of the message (all messages received at the socket
    # get a monotonically incrementing +seq+, and +message+ is the message itself.
    # 
    # To reply from an xrep handler, be sure to call send messages with the same +identities+ and +seq+
    # arguments that +on_recv+ had. So, send_message takes +message+, +identities+, and +seq+
    def zmq_xrep(address,socket_ctype,opts={})
      zmq_handler(DripDrop::ZMQXRepHandler,:xrep_socket,address,socket_ctype,opts)
    end
 
    # See the documentation for +zmq_xrep+ for more info
    def zmq_xreq(address,socket_ctype,opts={})
      zmq_handler(DripDrop::ZMQXReqHandler,:xreq_socket,address,socket_ctype,opts)
    end

    # Binds an EM websocket connection to +address+. takes blocks for
    # +on_open+, +on_recv+, +on_close+ and +on_error+.
    #
    # For example +on_recv+ could be used to echo incoming messages thusly:
    #    websocket(addr).on_open {|ws|
    #      ws.send_message(:name => 'ws_open_ack')
    #    }.on_recv {|msg,ws|
    #      ws.send(msg)
    #    }.on_close {|ws|
    #    }.on_error {|ws|
    #    }
    #
    # The +ws+ object that's passed into the handlers is not
    # the +DripDrop::WebSocketHandler+ object, but an em-websocket object.
    def websocket(address,opts={})
      uri     = URI.parse(address)
      h_opts  = handler_opts_given(opts)
      handler = DripDrop::WebSocketHandler.new(uri,h_opts)
      handler
    end
    
    # Starts a new Thin HTTP server listening on address.
    # Can have an +on_recv+ handler that gets passed +msg+ and +response+ args.
    #    http_server(addr) {|msg,response| response.send_message(msg)}
    def http_server(address,opts={},&block)
      uri     = URI.parse(address)
      h_opts  = handler_opts_given(opts)
      handler = DripDrop::HTTPServerHandler.new(uri, h_opts,&block)
      handler
    end
    
    # An EM HTTP client.
    # Example:
    #    client = http_client(addr)
    #    client.send_message(:name => 'name', :body => 'hi') do |resp_msg|
    #      puts resp_msg.inspect
    #    end
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
