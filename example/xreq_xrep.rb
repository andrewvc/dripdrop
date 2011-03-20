require 'dripdrop/node'
Thread.abort_on_exception = true

DripDrop::Node.new do
  route :xrep_server, :zmq_xrep, 'tcp://127.0.0.1:2200', :bind
  route :xreq_client, :zmq_xreq, xrep_server.address,    :connect
   
  xrep_server.on_receive do |message,response|
    puts "REP #{message.body}"
    response.send_message(message)
  end

  i = 0; k = 0
  EM::PeriodicTimer.new(1) do
    i += 1; k += 1
     
    xreq_client.send_message(:name => 'test', :body => "Test Payload i#{i}") do |message|
      puts "RECV I RESP #{message.inspect}"
    end
    xreq_client.send_message(:name => 'test', :body => "Test Payload k#{i}") do |message|
      puts "RECV K RESP #{message.inspect}"
    end
  end
end.start!
