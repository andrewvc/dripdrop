require 'dripdrop'
Thread.abort_on_exception = true

class ComplexExample < DripDrop::Node
  def initialize(mode=:all)
    super()
    @mode = mode
  end
  
  def action
    if [:all, :websockets].include?(@mode)
      route :ws_listener,  :websocket, 'ws://127.0.0.1:8080'
      route :broadcast_in, :zmq_subscribe, 'tcp://127.0.0.1:2200', :connect
      route :reqs_out,     :zmq_xreq,      'tcp://127.0.0.1:2201', :connect
      
      WSListener.new(:ws => ws_listener, :broadcast_in => broadcast_in, :reqs_out => reqs_out).run
    end
    
    if [:all, :coordinator].include?(@mode)
      route :broadcast_out, :zmq_publish, 'tcp://127.0.0.1:2200', :bind
      route :reqs_in,       :zmq_xrep,    'tcp://127.0.0.1:2201', :bind
      route :reqs_htout,    :http_client, 'tcp://127.0.0.1:3000/endpoint'
      
      Coordinator.new(:broadcast_out => broadcast_out, :reqs_in => reqs_in, :reqs_htout => reqs_htout).run
    end
  end
end

class Coordinator
  def initialize(opts={})
    @bc_out  = opts[:broadcast_out]
    @reqs_in = opts[:reqs_in]
    @reqs_htout = opts[:reqs_htout]
  end
  
  def run
    proxy_reqs
    heartbeat
  end

  def proxy_reqs
    @reqs_in.on_recv do |message, response|
      puts "Proxying #{message.inspect} to htout"
      @reqs_htout.send_message(message) do |http_response|
        puts "Received http response #{http_response.inspect} sending back"
        response.send_message(http_response)
      end
    end
  end
  
  def heartbeat
    EM::PeriodicTimer.new(1) do
      @bc_out.send_message :name => 'tick', :body => Time.now.to_s
    end
  end
end

class WSListener
  def initialize(opts={})
    @ws       = opts[:ws]
    @bc_in    = opts[:broadcast_in]
    @reqs_out = opts[:reqs_out]
    @client_channel = EM::Channel.new
  end
  def run
    proxy_websockets
    broadcast_to_websockets
  end

  def broadcast_to_websockets
    # Receives messages from Broadcast Out
    @bc_in.on_recv do |message|
      puts "Broadcast In recv: #{message.inspect}"
      @client_channel.push(message)
    end
  end

  def proxy_websockets
    ws = @ws
    
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

    ws.on_recv do |message,conn|
      puts "WS Recv #{message.name}"
      @reqs_out.send_message(message) do |resp_message|
        puts "Recvd resp_message #{resp_message.inspect}, sending back to client"
        conn.send_message(resp_message)
      end
    end
  end
end   
    

puts "Starting..."
ComplexExample.new.start!
