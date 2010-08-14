# dripdrop

0MQ Based App Event Monitoring / processing.
A work in progress.

## An example with a WebSocket UI:

To run a simple example, feeding data to a websockets UI
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
