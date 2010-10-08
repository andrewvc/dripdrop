require 'dripdrop/node'
Thread.abort_on_exception = true

DripDrop::Node.new do
  addr = 'http://127.0.0.1:2200'
  
  i = 0 
  http_server(addr).on_recv do |response,msg|
    i += 1
    response.send_message(msg)
  end

  EM::PeriodicTimer.new(1) do
    client = http_client(addr)
    msg = DripDrop::Message.new('http/status', :body => "Success #{i}")
    client.send_message(msg) do |resp_msg|
      puts resp_msg.inspect
    end
  end

  #Keep zmqmachine from spinning around using up all our CPU by creating a socket
  req = zmq_xreq('tcp://127.0.0.1:2091', :connect)
end.start!
