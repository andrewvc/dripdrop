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
    end.start! #Start the reactor and block until complete

Want to see a longer example encapsulating both zmqmachine and eventmachine functionality? Check out [this file](http://github.com/andrewvc/dripdrop-webstats/blob/master/lib/dripdrop-webstats.rb), which encapsulates all the functionality of the diagram below:

![topology](http://github.com/andrewvc/dripdrop/raw/master/doc_img/topology.png "Topology")

#How It Works

DripDrop encapsulates both zmqmachine, and eventmachine. It provides some sane default messaging choices, using [BERT](http://github.com/blog/531-introducing-bert-and-bert-rpc) (A binary, JSON, like serialization format) and JSON for serialization. While zmqmachine and eventmachine APIs, some convoluted ones, the goal here is to smooth over the bumps, and make them play together nicely.

Copyright (c) 2010 Andrew Cholakian. See LICENSE for details.
