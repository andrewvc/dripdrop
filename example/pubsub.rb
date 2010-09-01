require 'dripdrop/node'
require 'sinatra/base'
Thread.abort_on_exception = true

DripDrop::Node.new do |node|
  z_addr = 'tcp://127.0.0.1:2200'
    
  pub = node.zmq_publish(z_addr)
  sub = node.zmq_subscribe(z_addr).on_recv do |message|
    puts "Receiver 1 #{message.inspect}"
  end
  sub = node.zmq_subscribe(z_addr).on_recv do |message|
    puts "Receiver 2 #{message.inspect}"
  end
  
  node.zm_reactor.periodical_timer(5) do
    pub.send_message(DripDrop::Message.new('test', :body => 'Test Payload'))
  end
end
