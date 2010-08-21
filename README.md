# dripdrop

0MQ Toolset. A work in progress.
The goal here is to set up a standard message format, and toolchain to make async 0MQ apps easy to build.

Hopefully, by standardizing on a message format and patterns, composable apps can be built from these blocks.
Still a very rough work in progress, however, check out the rack-stats example.

#An Example

The rack stats app works as follows:

![topology](http://github.com/andrewvc/dripdrop/raw/master/doc_img/topology.png "Topology")

The forwarder, mongo logging, and web socket interface work using the code below:
You'll want to start up the webserver with: `thin start -R config.ru` in the examples/rack-stats folder
You'll start up the core with just `ruby core.rb` and if you want to connect the console via zmq try `ruby console-logger.rb`

    DripDrop::Node.new do |node|
      ###
      ### ZMQ Forwarder
      ###
      fwd_pub = node.zmq_publish(FORWARDER_OUT)
      node.zmq_subscribe(FORWARDER_IN,:socket_ctype => :bind).on_recv_raw do |message|
        fwd_pub.send_message(message)
        print 'f'
      end

      ###
      ### Persist all data to a MongoDB Instance
      ###
      db = EM::Mongo::Connection.new.db('dripdrop')
      collection = db.collection('stats')
      node.zmq_subscribe(FORWARDER_OUT).on_recv do |message|
        hash = collection.insert(Hash.new)
        print 'm'
      end
      
      ###
      ###  Broadcast a ZMQ sub socket out to web sockets
      ###
      node.websocket(WEBSOCKET_ADDR).on_open {|ws|
        #This actually isn't the most efficient way to do this, normally
        #you'd do one sub socket per process + node.recv_internal,
        #but this is here for fun.
        node.zmq_subscribe(FORWARDER_OUT).on_recv {|message|
          print 'w'
          ws.send(message.to_hash.to_json)
        }
      }
    end

## Copyright

Copyright (c) 2010 Andrew Cholakian. See LICENSE for details.
