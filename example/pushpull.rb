require 'dripdrop/node'
Thread.abort_on_exception = true

DripDrop::Node.new do |node|
  z_addr = 'tcp://127.0.0.1:2200'
   
  node.zmq_pull(z_addr, :socket_ctype => :connect).on_recv do |message|
    puts "Receiver 2 #{message.body}"
  end
  node.zmq_pull(z_addr, :socket_ctype => :connect).on_recv do |message|
    puts "Receiver 1 #{message.body}"
  end
  push = node.zmq_push(z_addr, :socket_ctype => :bind)

  i = 0
  node.zm_reactor.periodical_timer(800) do
    i += 1
    puts i
    push.send_message(DripDrop::Message.new('test', :body => "Test Payload #{i}"))
  end
end
