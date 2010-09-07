require 'dripdrop/node'
Thread.abort_on_exception = true

DripDrop::Node.new do |node|
  addr = 'http://127.0.0.1:2200'
  
  i = 0 
  node.http_server(addr).on_recv do |response,msg|
    i += 1
    response.send_message(msg)
  end

  #Looks like em's http client can't send bodies in requests...
  #once I fix this, this will work...
  #EM::PeriodicTimer.new(1) do
  #  client = node.http_client(addr)
  #  msg = DripDrop::Message.new('http/status', :body => "Success #{i}")
  #  client.send_message(msg) do |resp_msg|
  #    puts resp_msg.inspect
  #  end
  #end

  #Keep zmqmachine from spinning around using up all our CPU by creating a socket
  req = node.zmq_xreq('tcp://127.0.0.1:2091', :connect)
end
