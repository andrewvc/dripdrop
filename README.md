# DripDrop

**Note: For now, for PUSH/PULL support you'll need to build zmqmachine from my fork of zmqmachine, the official gem does not yet have this**

DripDrop is ZeroMQ(using zmqmachine) + Event Machine simplified for the general use case + serialization helpers.

Here's an example of the kind of thing DripDrop makes easy, from [example/combined.rb](http://github.com/andrewvc/dripdrop/blob/master/example/combined.rb)
  
    require 'dripdrop'
    Thread.abort_on_exception = true #Always a good idea in multithreaded apps.

    #Define our handlers
    DripDrop::Node.new do
    #Create a publisher
      route :stats_pub,      :zmq_publish,   'tcp://127.0.0.1:2200', :bind
      route :stats_sub1,     :zmq_subscribe, stats_pub.address, :connect
      route :stats_sub2,     :zmq_subscribe, stats_pub.address, :connect
      route :http_collector, :http_server,   'http://127.0.0.1:8080'
      route :http_agent,     :http_client,   http_collector.address
        
      stats_sub1.on_recv do |message|
        puts "Receiver 1: #{message.body}"
      end
      stats_sub2.on_recv do |message|
        puts "Receiver 2: #{message.body}"
      end
      
      i = 0
      http_collector.on_recv do |message,response|
        i += 1
        stats_pub.send_message(message)
        response.send_message(:name => 'ack', :body => {:seq => i})
      end

      EM::PeriodicTimer.new(1) do
        msg = DripDrop::Message.new('http/status', :body => "Success #{i}")
        http_agent.send_message(msg) do |resp_msg|
          puts "RESP: #{resp_msg.body['seq']}"
        end
      end
    end.start! #Start the reactor and block until complete

Note that these aren't regular ZMQ sockets, and that the HTTP server isn't a regular server. They only speak and respond using DripDrop::Message formatted messages. For HTTP/WebSockets it's JSON that looks like {name: 'name', head: {}, body: anything}, for ZeroMQ it means BERT. There is a raw mode that you can use for other message formats, but using DripDrop::Messages makes things easier, and for some socket types (like XREQ/XREP) the predefined format is very useful in matching requests to replies.

#RDoc

RDocs can be found [here](http://www.rdoc.info/github/andrewvc/dripdrop/master/frames). Most of the interesting stuff is in the [Node](http://www.rdoc.info/github/andrewvc/dripdrop/master/DripDrop/Node) and [Message](http://www.rdoc.info/github/andrewvc/dripdrop/master/DripDrop/Message) classes.

#How It Works

DripDrop encapsulates both zmqmachine, and eventmachine. It provides some sane default messaging choices, using [BERT](http://github.com/blog/531-introducing-bert-and-bert-rpc) (A binary, JSON, like serialization format) and JSON for serialization. While zmqmachine and eventmachine APIs, some convoluted ones, the goal here is to smooth over the bumps, and make them play together nicely.

#Contributors

* Andrew Cholakian: [andrewvc](http://github.com/andrewvc)
* John W Higgins: [wishdev](http://github.com/wishdev)
