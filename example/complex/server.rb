require 'dripdrop'
Thread.abort_on_exception = true

class ComplexExample < DripDrop::Node
  def initialize(mode=:all)
    super()
    @mode = mode
  end
  
  def action
    if [:all, :websockets].include?(@mode)
      route :ws_listener, :websocket, 'ws://127.0.0.1:8080'
      route :broadcast_in, :zmq_subscribe, 'tcp://127.0.0.1:2200', :connect
      
      WSListener.new(:ws => ws_listener, :broadcast_in => broadcast_in).run
    end
    
    if [:all, :broadcaster].include?(@mode)
      route :broadcast_out, :zmq_publish, 'tcp://127.0.0.1:2200', :bind
      
      EM::PeriodicTimer.new(1) do
        puts "Sending Tick"
        broadcast_out.send_message(:name => 'tick', :body => Time.now.to_s)
      end
    end
  end
end

class WSListener
  def initialize(opts={})
    @ws = opts[:ws]
    @bc_in = opts[:broadcast_in]
    @client_channel = EM::Channel.new
  end
  def run
    ws = @ws
    ws.on_open do |ws_conn|
      puts "Saying hello"
      ws_conn.send_message(DripDrop::Message.new('test'))
      
      sid = @client_channel.subscribe do |message|
        puts message.inspect
        ws_conn.send_message(message)
      end
      
      ws.on_close do
        puts "Closed #{sid}"
        @client_channel.unsubscribe sid
      end
      ws.on_error do
        puts "Errored #{sid}"
        @client_channel.unsubscribe sid
      end
    end
    
    # Receives messages from Broadcast Out
    @bc_in.on_recv do |message|
      puts "Broadcast In recv: #{message.inspect}"
      @client_channel.push(message)
    end
  end
end   
    

puts "Starting..."
ComplexExample.new.start!
