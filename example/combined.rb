require 'dripdrop'
Thread.abort_on_exception = true #Always a good idea in multithreaded apps.

# Encapsulates our EM and ZMQ reactors
DripDrop::Node.new do
  # Define all our sockets
  route :stats_pub,      :zmq_publish,   'tcp://127.0.0.1:2200', :bind
  route :stats_sub1,     :zmq_subscribe, stats_pub.address, :connect
  route :stats_sub2,     :zmq_subscribe, stats_pub.address, :connect
  route :http_collector, :http_server,   'http://127.0.0.1:8080'
  route :http_agent,     :http_client,   http_collector.address
    
  stats_sub1.on_receive do |message|
    puts "Receiver 1: #{message.body}"
  end
  stats_sub2.on_receive do |message|
    puts "Receiver 2: #{message.body}"
  end
  
  i = 0
  http_collector.on_receive do |message,response|
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
