# DripDrop

**Note, this is a work in progress, right now I'm stomping around the codebase breaking a lot of things that worked only a short while ago. Expect this to be fixed by sunday, Sept 5 however. And no, I won't branch because the old code sucked (truly).**

DripDrop is ZeroMQ(using zmqmachine) + Event Machine simplified for the general use case + serialization helpers.

Here's an example of the kind of thing DripDrop makes easy, from [examples/pubsub.rb](http://github.com/andrewvc/dripdrop/blob/master/example/pubsub.rb)
 
    DripDrop::Node.new do |node|
      z_addr = 'tcp://127.0.0.1:2200'

      pub = node.zmq_publish(z_addr,:bind)
      sub = node.zmq_subscribe(z_addr,:connect).on_recv do |message|
        puts "Receiver 1 #{message.inspect}"
      end
      sub = node.zmq_subscribe(z_addr, :connect).on_recv do |message|
        puts "Receiver 2 #{message.inspect}"
      end

      node.zm_reactor.periodical_timer(5) do
        pub.send_message(DripDrop::Message.new('test', :body => 'Test Payload'))
      end
    end
   

Want to see a longer example encapsulating both zmqmachine and eventmachine functionality? Check out [this file](http://github.com/andrewvc/dripdrop-webstats/blob/master/lib/dripdrop-webstats.rb), which encapsulates all the functionality of the diagram below:

![topology](http://github.com/andrewvc/dripdrop/raw/master/doc_img/topology.png "Topology")

#How It Works

DripDrop encapsulates both zmqmachine, and eventmachine. It provides some sane default messaging choices, using [BERT](http://github.com/blog/531-introducing-bert-and-bert-rpc) (A binary, JSON, like serialization format) and JSON to automatically. zmqmachine and eventmachine have some good APIs, some convoluted ones, the goal here is to smooth over the bumps, and make writing highly concurrent programs both as terse and beautiful as possible.

Copyright (c) 2010 Andrew Cholakian. See LICENSE for details.
