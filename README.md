# DripDrop

**Note: For now, for PUSH/PULL support you'll need to build zmqmachine from my fork of zmqmachine, the official gem does not yet have this**

DripDrop is ZeroMQ(using zmqmachine) + Event Machine simplified for the general use case + serialization helpers.

Here's an example of the kind of thing DripDrop makes easy, from [examples/pubsub.rb](http://github.com/andrewvc/dripdrop/blob/master/example/pubsub.rb)
 
    require 'dripdrop/node'
    Thread.abort_on_exception = true

    #Define our handlers
    DripDrop::Node.new do
      z_addr = 'tcp://127.0.0.1:2200'
        
      #Create a publisher
      pub = zmq_publish(z_addr,:bind)

      #Create two subscribers
      zmq_subscribe(z_addr,:connect).on_recv do |message|
        puts "Receiver 1 #{message.inspect}"
      end
      zmq_subscribe(z_addr, :connect).on_recv do |message|
        puts "Receiver 2 #{message.inspect}"
      end
      
      zm_reactor.periodical_timer(5) do
        #Sending a hash as a message implicitly transforms it into a DripDrop::Message
        pub.send_message(:name => 'test', :body => 'Test Payload')
      end
      
      http_server(addr).on_recv do |response,msg|
        i += 1
        response.send_message(msg)
      end

      EM::PeriodicTimer.new(1) do
        client = http_client(addr)
        msg = DripDrop::Message.new('http/status', :body => "Success #{i}")
        client.send_message(msg) do |resp_msg|
          puts resp_msg.inspect
        end
      end
    end.start! #Start the reactor and block until complete

Note that these aren't regular ZMQ sockets, and that the HTTP server isn't a regular server. They only speak and respond using DripDrop::Message formatted messages. For HTTP/WebSockets it's JSON that looks like {name: 'name', head: {}, body: anything}, for ZeroMQ it means BERT. There is a raw made that you can use for other message formats, but using DripDrop::Messages makes things easier, and for some socket types (like XREQ/XREP) the predefined format is very useful in matching requests to replies.

Want to see a longer example encapsulating both zmqmachine and eventmachine functionality? Check out [this file](http://github.com/andrewvc/dripdrop-webstats/blob/master/lib/dripdrop-webstats.rb).

#RDoc

RDocs can be found [here](http://www.rdoc.info/github/andrewvc/dripdrop/master/frames). Most of the interesting stuff is in the [Node](http://www.rdoc.info/github/andrewvc/dripdrop/master/DripDrop/Node) and [Message](http://www.rdoc.info/github/andrewvc/dripdrop/master/DripDrop/Message) classes.

#How It Works

DripDrop encapsulates both zmqmachine, and eventmachine. It provides some sane default messaging choices, using [BERT](http://github.com/blog/531-introducing-bert-and-bert-rpc) (A binary, JSON, like serialization format) and JSON for serialization. While zmqmachine and eventmachine APIs, some convoluted ones, the goal here is to smooth over the bumps, and make them play together nicely.

#Contributors

Andrew Cholakian: [andrewvc](http://github.com/andrewvc)
John W Higgins: [wishdev](http://github.com/wishdev)

Copyright (c) 2010 Andrew Cholakian. See LICENSE for details.
