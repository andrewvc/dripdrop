require 'dripdrop/node'
Thread.abort_on_exception = true

DripDrop::Node.new do |node|
  z_addr = 'tcp://127.0.0.1:2200'
   
  rep = node.zmq_xrep(z_addr, :bind)
  rep.on_recv do |message|
    puts "REP #{message.body}"
    rep.send_message(message)
  end

  req = node.zmq_xreq(z_addr, :connect)
  
  i = 0
  k = 0
  req.send_message(DripDrop::Message.new('test', :body => "Test Payload i#{i}")) do |message|
    puts "RECV I RESP #{message.inspect}"
  end
  req.send_message(DripDrop::Message.new('test', :body => "Test Payload k#{i}")) do |message|
    puts "RECV K RESP #{message.inspect}"
  end
end
