require 'rubygems'
require 'ffi-rzmq'
require 'eventmachine'
require 'uri'
require 'resolv'
require 'ipaddr'

require 'dripdrop/message'
require 'dripdrop/node/nodelet'
require 'dripdrop/handlers/base'
require 'dripdrop/handlers/zeromq'
require 'dripdrop/handlers/websockets'
require 'dripdrop/handlers/http_client'

begin
  require 'dripdrop/handlers/http_server'
rescue LoadError => e
  $stderr.write "Warning, could not load http server, your probably don't have eventmachine_httpserver installed\n"
end

class DripDrop
  class Node
    ZCTX = ZMQ::Context.new 1
    
    attr_reader   :zm_reactor, :routing, :nodelets, :run_list
    attr_accessor :debug
    
    def initialize(opts={},&block)
      @block      = block
      @thread     = nil # Thread containing the reactors
      @routing    = {}  # Routing table
      @run_list   = opts['run_list'] || opts[:run_list] || nil  #List of nodelets to run
      @run_list   = @run_list.map(&:to_sym) if @run_list
      @debug      = opts[:debug]
      @recipients_for       = {}
      @handler_default_opts = {:debug => @debug}
      @nodelets   = {}  # Cache of registered nodelets
      @zctx = ZCTX
    end

    # Starts the reactors and runs the block passed to initialize.
    # This is non-blocking.
    def start
      @thread = Thread.new do
        EM.error_handler {|e| self.error_handler e}
        EM.run { action }
      end
    end

    # Blocking version of start, equivalent to +start+ then +join+
    def start!
      self.start
      self.join
    end

    # Stops the reactors. If you were blocked on #join, that will unblock.
    def stop
      EM.stop
    end

    # When subclassing +DripDrop::Node+ you probably want to define this method
    # Otherwise it will attempt to run the @block passed into +DripDrop::Node.new+
    def action
      if @block
        self.instance_eval(&@block)
      else
        raise "Could not start, no block or specified"
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
      route_full(nil, name, handler_type, *handler_args)
    end
  
    # Probably not useful for most, apps. This is used internally to 
    # create a route for a given nodelet.
    def route_full(nodelet, name, handler_type, *handler_args)
      # If we're in a route_for block, prepend appropriately
      full_name = (nodelet && nodelet.name) ? "#{nodelet.name}_#{name}".to_sym : name
      
      handler = self.send(handler_type, *handler_args)
      @routing[full_name] = handler
      
      # Define the route name as a singleton method
      (class << self; self; end).class_eval do
        define_method(full_name) { handler }
      end
      
      handler
    end

    # DEPRECATED, will be deleted in 0.8
    def routes_for(nodelet_name,&block)
      $stderr.write "routes_for is now deprecated, use nodelet instead"
      nlet = nodelet(nodelet_name,&block)
      block.call(nlet)
    end

    # Nodelets are a way of segmenting a DripDrop::Node. This can be used
    # for both organization and deployment. One might want the production
    # deployment of an app to be broken across multiple servers or processes
    # for instance:
    #
    #    nodelet :heartbeat do |nlet|
    #      nlet.route :ticker, :zmq_publish, 'tcp://127.0.0.1', :bind
    #      EM::PeriodicalTimer.new(1) do
    #        nlet.ticker.send_message(:name => 'tick')
    #      end
    #    end
    #
    # Nodelets can also be subclassed, for instance:
    # 
    #    class SpecialNodelet < DripDrop::Node::Nodelet
    #      def action
    #        nlet.route :ticker, :zmq_publish, 'tcp://127.0.0.1', :bind
    #        EM::PeriodicalTimer.new(1) do
    #          nlet.ticker.send_message(:name => 'tick')
    #        end
    #      end
    #    end
    #
    #    nodelet :heartbeat, SpecialNodelet
    #
    # If you specify a block, Nodelet#action will be ignored and the block
    # will be run
    # 
    # Nodelets are made available as instance methods on the current DripDrop::Nodelet
    # Object, so the following works as well:
    #
    #    nodelet :mynodelet
    #    
    #    mynodelet.route :route_name, :zmq_xreq, 'tcp://127.0.0.1:2000', ;bind
    def nodelet(name,klass=Nodelet,*configure_args,&block)
      # If there's a run list, only run nodes in that list
      return nil if @run_list && !@run_list.include?(name.to_sym)
       
      nlet = @nodelets[name] ||= klass.new(self,name,*configure_args)
      
      # Define a method returning the nodelet in the current node
      unless respond_to?(name)
       (class << self; self; end).class_eval do
          define_method(name) { nlet }
        end
      end
       
      if block
        block.call(nlet)
      else
        nlet.action
      end
      nlet
    end
    
    # Creates a ZMQ::SUB type socket. Can only receive messages via +on_recv+.
    # zmq_subscribe sockets have a +topic_filter+ option, which restricts which
    # messages they can receive. It takes a regexp as an option.
    def zmq_subscribe(address,socket_ctype,opts={},&block)
      zmq_handler(DripDrop::ZMQSubHandler,ZMQ::SUB,address,socket_ctype,opts)
    end

    # Creates a ZMQ::PUB type socket, can only send messages via +send_message+
    def zmq_publish(address,socket_ctype,opts={})
      zmq_handler(DripDrop::ZMQPubHandler,ZMQ::PUB,address,socket_ctype,opts)
    end

    # Creates a ZMQ::PULL type socket. Can only receive messages via +on_recv+
    def zmq_pull(address,socket_ctype,opts={},&block)
      zmq_handler(DripDrop::ZMQPullHandler,ZMQ::PULL,address,socket_ctype,opts)
    end

    # Creates a ZMQ::PUSH type socket, can only send messages via +send_message+
    def zmq_push(address,socket_ctype,opts={})
      zmq_handler(DripDrop::ZMQPushHandler,ZMQ::PUSH,address,socket_ctype,opts)
    end

    # Creates a ZMQ::XREP type socket, both sends and receivesc XREP sockets are extremely
    # powerful, so their functionality is currently limited. XREP sockets in DripDrop can reply
    # to the original source of the message.
    #
    # Receiving with XREP sockets in DripDrop is different than other types of sockets, on_recv
    # passes 2 arguments to its callback, +message+, and +response+. A minimal example is shown below:
    #
    #    
    #    zmq_xrep(z_addr, :bind).on_recv do |message,response|
    #      response.send_message(message)
    #    end
    #
    def zmq_xrep(address,socket_ctype,opts={})
      zmq_handler(DripDrop::ZMQXRepHandler,ZMQ::XREP,address,socket_ctype,opts)
    end
 
    # See the documentation for +zmq_xrep+ for more info
    def zmq_xreq(address,socket_ctype,opts={})
      zmq_handler(DripDrop::ZMQXReqHandler,ZMQ::XREQ,address,socket_ctype,opts)
    end

    # Binds an EM websocket connection to +address+. takes blocks for
    # +on_open+, +on_recv+, +on_close+ and +on_error+.
    #
    # For example +on_recv+ could be used to echo incoming messages thusly:
    #    websocket(addr).on_open {|conn|
    #      ws.send_message(:name => 'ws_open_ack')
    #    }.on_recv {|msg,conn|
    #      conn.send(msg)
    #    }.on_close {|conn|
    #    }.on_error {|reason,conn|
    #    }
    #
    # The +ws+ object that's passed into the handlers is not
    # the +DripDrop::WebSocketHandler+ object, but an em-websocket object.
    def websocket(address,opts={})
      uri     = URI.parse(address)
      h_opts  = handler_opts_given(opts)
      DripDrop::WebSocketHandler.new(uri,h_opts)
    end
    
    # Starts a new Thin HTTP server listening on address.
    # Can have an +on_recv+ handler that gets passed +msg+ and +response+ args.
    #    http_server(addr) {|msg,response| response.send_message(msg)}
    def http_server(address,opts={},&block)
      uri     = URI.parse(address)
      h_opts  = handler_opts_given(opts)
      DripDrop::HTTPServerHandler.new(uri, h_opts,&block)
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
      DripDrop::HTTPClientHandler.new(uri, h_opts)
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

    # Catch all error handler
    # Global to all DripDrop Nodes
    def self.error_handler(e)
      $stderr.write "#{e.class}: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
    end

    private
     
    def zmq_handler(klass, sock_type, address, socket_ctype, opts={})
      addr_uri = URI.parse(address)
      
      host_str = addr_uri.host
      #if addr_uri.scheme == 'tcp'  
      #  host = Resolv.getaddresses(addr_uri.host).first
      #  host_addr = Resolv.getaddresses('localhost').map {|a| IPAddr.new(a)}.find {|a| a.ipv4?}
      #  host_str  = host_addr.ipv6? ? "[#{host_addr.to_s}]" : host_addr.to_s
      #else
      #  host_str = addr_uri.host
      #end

      z_addr      =  "#{addr_uri.scheme}://#{host_str}:#{addr_uri.port.to_i}"
      h_opts      = handler_opts_given(opts)
      connection = EM::ZeroMQ.create @zctx, sock_type, socket_ctype, address, klass.new(h_opts)
      handler            = connection.handler
      handler.connection = connection
      handler.post_setup
      handler
    end   
    
    def handler_opts_given(opts)
      @handler_default_opts.merge(opts)
    end
  end
end
