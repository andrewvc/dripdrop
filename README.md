# dripdrop

0MQ Based App Event Monitoring / processing.
A work in progress.

# Why use dripdrop?

You want to record stats for your app, or otherwise process messages.
dripdrop does this well for a few reasons.

* It's fast. dripdrop doesn't slow down your app. 0MQ + Bert are fast. Sending a message never blocks, even if the conn dies.
* It's flexible. By leveraging 0MQ pub/sub sockets you can have many different processors (collectors in dripdrop) that don't impact or even care about each other
* It's easy. Check out the agent and collector examples below. You can be processing stuff in no time.

## An example with a WebSocket UI:

### You'll need to have the zmq dev libs on your machine. On OSX this means

1. Download and build zeromq from [zeromq.org](http://www.zeromq.org/area:download)
1. The agent just uses the plain zmq gem, which runs fine on ruby 1.8.7+, this is so you can use it in say your rails app. Everything else needs ruby 1.9.2 or jruby and uses Chuck Remes [ffi-rzmq](http://github.com/chuckremes/ffi-rzmq), and [zmqmachine](http://github.com/chuckremes/zmqmachine) gems which you must build yourself. I recommend using rvm to enable the use of multiple rubies on one machine.
1. zmq_forwarder comes with zmq, use this to aggregate agent messages using the example config shown below

### To run a simple example, feeding data to a websockets UI

#### Aggregate agents with zmq_forwarder (comes with zmq)
    $ zmq_forwarder examples/forwarder.cfg

#### Start up the drip drop publisher example
    $ drip-publisher

#### Assuming you have mongodb running
    $ drip-mlogger
  
#### Start up a webserver to host the HTML/JS for a sample websocket client
    $ cd DRIPDROPFOLDER/example/web/
    $ ruby server

## Example Topology

You can add as many listeners as you want, or reconfigure things any way you want. Heres how I plan on using it.

![topology](http://github.com/andrewvc/dripdrop/raw/master/doc_img/topology.png "Topology")

## Sending Messages

Sending messages is easy with the agent, an example:

    require 'rubygems'
    require 'dripdrop/agent'

    agent = DripDrop::Agent.new('tcp://127.0.0.1:2900')

    loop do
      #Test is the message name, this is the first part of the 0MQ message, used for filtering
      #at the 0MQ sub socket level, :head is always a hash,  :body is freeform
      #EVERYTHING must be serializable to BERT
      agent.send_message('test', :body => 'hello', :head => {:key => 'value'})
      puts "SEND"
      sleep 1
    end

## Writing a custom message processor

Writing custom message processors is super easy, just create a new DripDrop::Collector
and run it. DripDrop::Collector is based on Chuck Remes' awesome zmqmachine, an evented
0MQ processor. Heres' the MongoDB logger as an example:
    
    require 'rubygems'
    require 'mongo'
    require 'dripdrop/collector'

    class DripDrop
      class MLoggerCollector < Collector
        attr_accessor :mongo_collection
        
        #Messages are a DripDrop::Message
        def on_recv(message)
          if @mongo_collection
            @mongo_collection.insert(message.to_hash)
          end
        end
      end

      class MLogger
        attr_reader :sub_address, :sub_reactor, :mongo_host, :mongo_port, :mongo_db,
                    :mongo_connection, :mongo_collection

        def initialize(sub_address='tcp://127.0.0.1:2901',mhost='127.0.0.1',mport=27017,mdb='dripdrop')
          @sub_address   = URI.parse(sub_address)
          @sub_collector = MLoggerCollector.new('tcp://127.0.0.1:2901')
          
          @mongo_host, @mongo_port, @mongo_db = mhost, mport, mdb
          @mongo_connection = Mongo::Connection.new(@mongo_host,@mongo_port).db(@mongo_db)
          @mongo_collection = @mongo_connection.collection('raw')
        end

        def run
          @sub_collector.mongo_collection = @mongo_collection
          @sub_collector.run.join
        end
      end
    end


## Note on Patches/Pull Requests
 
* Fork the project.
* Make your feature addition or bug fix.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

## Copyright

Copyright (c) 2010 Andrew Cholakian. See LICENSE for details.
