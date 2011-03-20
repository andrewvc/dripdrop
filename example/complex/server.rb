require 'dripdrop'
Thread.abort_on_exception = true

class ComplexExample < DripDrop::Node
  def initialize(mode=:all)
    super()
    @mode = mode
  end
  
  def action
    nodelet :ws_listener, WSListener do |n|
      n.route :ws_listener,  :websocket, 'ws://127.0.0.1:8080'
      n.route :broadcast_in, :zmq_subscribe, 'tcp://127.0.0.1:2200', :connect
      n.route :reqs_out,     :zmq_xreq,      'tcp://127.0.0.1:2201', :connect
    end
      
    nodelet :coordinator, Coordinator do |n|
      n.route :broadcast_out, :zmq_publish, 'tcp://127.0.0.1:2200', :bind
      n.route :reqs_in,       :zmq_xrep,    'tcp://127.0.0.1:2201', :bind
      n.route :reqs_htout,    :http_client, 'tcp://127.0.0.1:3000/endpoint'
    end
  end
end

class Coordinator < DripDrop::Node::Nodelet
  def run
    proxy_reqs
    heartbeat
  end

  def proxy_reqs
    reqs_in.on_receive do |message, response|
      puts "Proxying #{message.inspect} to htout"
      reqs_htout.send_message(message) do |http_response|
        puts "Received http response #{http_response.inspect} sending back"
        response.send_message(http_response)
      end
    end
  end
  
  def heartbeat
    EM::PeriodicTimer.new(1) do
      broadcast_out.send_message :name => 'tick', :body => Time.now.to_s
    end
  end
end

class WSListener < DripDrop::Node::Nodelet
  def initialize(*args)
    super
    @client_channel = EM::Channel.new
  end
  
  def run
    proxy_websockets
    broadcast_to_websockets
  end

  def broadcast_to_websockets
    # Receives messages from Broadcast Out
    broadcast_in.on_receive do |message|
      puts "Broadcast In recv: #{message.inspect}"
      @client_channel.push(message)
    end
  end

  def proxy_websockets
    sigs_sids = {} #Map connection signatures to subscriber IDs
     
    ws.on_open do |conn|
      puts "WS Connected"
      conn.send_message(DripDrop::Message.new('test'))
      
      sid = @client_channel.subscribe do |message|
        puts message.inspect
        conn.send_message(message)
      end
       
      sigs_sids[conn.signature] = sid
    end
    ws.on_close do |conn|
      puts "Closed #{conn.signature}"
      @client_channel.unsubscribe sigs_sids[conn.signature]
    end
    ws.on_error do |reason,conn|
      puts "Errored #{reason.inspect}, #{conn.signature}"
      @client_channel.unsubscribe sigs_sids[conn.signature]
    end

    ws.on_receive do |message,conn|
      puts "WS Recv #{message.name}"
      reqs_out.send_message(message) do |resp_message|
        puts "Recvd resp_message #{resp_message.inspect}, sending back to client"
        conn.send_message(resp_message)
      end
    end
  end
end   
    

puts "Starting..."
ComplexExample.new.start!
