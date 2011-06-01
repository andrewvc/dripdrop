# Notice:

  DripDrop was a fun experiment, and I may start using it again in the future, but it is not actively maintained. There are no known bugs however, and its reasonably well tested (both in a bunch of sample apps I built and unit tests), so it should be OK to use, but be aware that if you find any issues with it, or want features added to it, it'll be up to you to hack on it! 

# DripDrop

## INSTALLATION NOTES:

1. This does NOT work with 1.8.7. 1.9.2/RBX/jRuby only.
2. Build zeromq2 from [git master](https://github.com/zeromq/zeromq2) if you haven't already.
3. Install with 'gem install dripdrop'.
4. If on jRuby, http servers will be unavailable unless you have a jruby with cext support, and manually `gem install eventmachine_httpserver`
5. If on 1.9.x `gem install ffi`

## About

DripDrop is a library aiming to help you write better message passing apps. It's a rich toolchest, currently based on EventMachine, which provides async IO. 

DripDrop helps in these ways:

  1. Normalized Communication Interfaces. All protocols, regardless of their using HTTP, ZeroMQ, or WebSockets, have a unified API, with minor differences only to accomodate the reality of the underlying protocol.
  2. A set of tools to break your app into composable parts--we call them nodelets in dripdrop--ideally communicating with each other with the aforementioned interfaces..
  3. A simple, yet powerful messaging class, that lets you control the structure, formatting, and serialization of messages sent between nodelets.
  4. Tools to break your nodelets off when it comes time to deploy, letting you scale your app by delegating roles and scaling out resources

## Normalized Interfaces

Let's start by looking at the normalized communication interface in a simple app.
    
    class MyApp < DripDrop::Node
      def action #Special method that gets executed on Node#start
        # Define some sockets, here we create an HTTP server, and
        # a client to it. :my_hts and :my_htc are custom names
        # that will be available after definition
        route :my_server, :http_server, 'http://127.0.0.1:2201'
        route :my_client, :http_client, 'http://127.0.0.1:2201'
        
        # Our http server is a simple time server
        my_server.on_receive do |message,response|
          response.send_message(:name => 'time', :body => {'time' => Time.now.to_s})
        end
        
        # Here, we setup a timer, and periodically poll the http server
        EM::PeriodicTimer.new(1) do
          # Messages must have a :name. They can optionally have a :body.
          # Additionally, they can set custom :head properties.
          my_client.send_message(:name => 'time_request') do |response_message|
            puts "The time is: #{response_message.body['time']}"
          end
        end
      end
    end
     
    #Start the app and block
    MyApp.new.start!

What we've done here is use HTTP as a simple messaging protocol. Yes, we've thrown out a good chunk of what HTTP does, but consider this, that exact same code would work if we replaced the top two lines with:

        route :my_server, :zmq_xrep, 'http://127.0.0.1:2201', :bind
        route :my_client, :zmq_xreq, 'http://127.0.0.1:2201', :connect

That replaces the HTTP server and client with ultra-high performance zeromq sockets. Now, protocols have varying strengths and weaknesses, and ZeroMQ is not HTTP necessarily, for instance, given a :zmq_pub socket, you can only send_messages, but there is no response message, because :zmq_pub is the publishing end of a request/reply pattern. The messaging API attempts to reduce all methods on sockets to the following set:

  * on_receive (sometimes takes a block with |message,response| if it can send a response)
  * send_message
  * on_open  (Websockets only)
  * on_close (Websockets only)


## Composable Parts

The tools mentioned above are useful, but if you try and build a larger app you'll quickly find them lacking. The callbacks get tricky, and mixing your logic up in a single #action method becomes messy. That's why we have nodelets in DripDrop. Here's a trivial example.

    class MyApp < DripDrop::Node
      def initialize(mode=:all)
        super()
        @mode = mode
      end
      
      def action
        # This will instantiate a new StatsCollector object, and define the
        # stats_raw and stats_filtered methods inside it.
        nodelet :stats_producer, StatsProducer do |n|
          n.route :stats_output, :zmq_push, 'tcp://127.0.0.1:2301', :bind
        end

        nodelet :stats_collector, StatsCollector do |n|
          n.route :stats_raw, :zmq_pull, 'tcp://127.0.0.1:2301', :connect
          n.route :stats_filtered, :zmq_push, 'tcp://127.0.0.1:2302', :bind
        end

        nodelet :stats_processor, StatsProcessor do |n|
          n.route :stats_ingress, :zmq_pull, 'tcp://127.0.0.1:2302', :connect
        end

        # The nodelets method gives you access to all defined nodelets as a hash
        # We created a #run method on each nodelet we call here.
        nodelets.each_value { |n| n.run }
      end
    end

    # You must subclass Nodelet
    # The method #run here is merely a convention
    class StatsProducer < DripDrop::Node::Nodelet
      def run
        EM::PeriodicTimer.new(1) do
          stats_output.send_message :name => 'stat', :body => Time.now.to_s
        end
      end
    end

    class StatsCollector < DripDrop::Node::Nodelet
      def run
        stats_raw.on_receive do |raw_stat_msg|
          stats_filtered.send_message(raw_stat_msg)
        end
      end
    end

    class StatsProcessor < DripDrop::Node::Nodelet
      # Initialize shouldn't be subclassed on a Nodelet, this gets called
      # After the nodelet is instantiated
      def configure
        @name_counts = Hash.new(0)
      end

      def run
        stats_ingress.on_receive do |message|
          @name_counts[message.name] += 1
          puts @name_counts.inspect
          puts "received message.body: " + message.body
        end
      end
    end

    MyApp.new.start!

# Custom Messages

  DripDrop::Message is the parent class of all messages in dripdrop, it's a flexible and freeform way to send data. In more complex apps you'll want to both define custom behaviour on messages, and restrict the data they carry. This is possible by subclassing DripDrop::Message. Before we look at that though, lets see what makes a DripDrop::Message. 

  The simplest DripDrop::Message you could create would look something like this if dumped into JSON:
    
    {name: 'msgname', head: {}, body: null}

  In other words, a dripdrop message *must* provide a name, it must also be able to store arbitrary, nested, keys and values in its head, and it may use the body for any data it wishes.

  If you'd like to create your own Message format, simply Subclass DripDrop::Message. If you want to restrict your handlers to using a specific message type, it's easily done by passing in the :message_class option. For instance

    class MyMessageClass < DripDrop::Message
      # Custom code
    end
    class MyApp < DripDrop::Node
      def action
        route :myhandler, :zmq_publish,   'tcp://127.0.0.1:2200', :bind,    :message_class => MyMessageClass 
        route :myhandler, :zmq_subscribe, 'tcp://127.0.0.1:2200', :connect, :message_class => MyMessageClass
      end
    end

# Breaking out your nodelets
  
One of the core ideas behind dripdrop, is that if your application is composed of a bunch of separate parts, that in production deployment, will run on separate physical servers, it should still be possible for you to develop and test with ease. If you structure your app into separate nodelets, and *only* communicate between them via message passing, you can accomplish this easily. 

While you will have to write your own executable wrappers suitable for your own deployment, one convenenience feature built in is the notion of a +run_list+. By setting the #run_list you can restrict which nodelets actually get initialized. For example:

    class MyApp < DripDrop::Node
      nodelet :service_one, ServiceOneClass do
        #nodelet setup
      end
      nodelet :service_two, ServiceTwoClass do
        #nodelet setup
      end
    end

    # Only starts :service_two, the setup for :service_one
    # is skipped as well
    MyApp.new(:run_list => [:service_two]).start!

#RDocs

RDocs can be found [here](http://www.rdoc.info/github/andrewvc/dripdrop/master/frames). Most of the interesting stuff is in the [Node](http://www.rdoc.info/github/andrewvc/dripdrop/master/DripDrop/Node) and [Message](http://www.rdoc.info/github/andrewvc/dripdrop/master/DripDrop/Message) classes.

#Contributors

* Andrew Cholakian: [andrewvc](http://github.com/andrewvc)
* John W Higgins: [wishdev](http://github.com/wishdev)
* Nick Recobra: [oruen](https://github.com/oruen)
