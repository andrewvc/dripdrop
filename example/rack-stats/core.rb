require 'rubygems'
require 'dripdrop/node'
require 'em-mongo'

#ZMQ Forwarder
FORWARDER_IN='tcp://127.0.0.1:2700'
FORWARDER_OUT='tcp://127.0.0.1:2701'

#Web Socket Output
WEBSOCKET_ADDR='ws://127.0.0.1:2702'

DripDrop::Node.new do |node|
  ###
  ### ZMQ Forwarder
  ###
  fwd_pub = node.zmq_publish(FORWARDER_OUT)
  fwd_sub = node.zmq_subscribe(FORWARDER_IN,:socket_ctype => :bind)
  fwd_sub.on_recv_raw do |message|
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
    #you'd do one sub socket per process, but this is here for fun
    node.zmq_subscribe(FORWARDER_OUT).on_recv {|message|
      print 'w'
      ws.send(message.to_hash.to_json)
    }
  }.on_recv {|message,ws|
  }.on_close {|ws|
    node.remove_recv_internal(:my_rebroadcast,ws)
  }.on_error {|ws|
    node.remove_recv_internal(:my_rebroadcast,ws)
  } 
end
