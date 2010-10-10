require 'dripdrop/node'
Thread.abort_on_exception = true

DripDrop::Node.new do
  z_addr = 'tcp://127.0.0.1:2200'
   
  zmq_pull(z_addr, :connect).on_recv do |message|
    puts "Receiver 2 #{message.body}"
  end
  zmq_pull(z_addr, :connect).on_recv do |message|
    puts "Receiver 1 #{message.body}"
  end
  push = zmq_push(z_addr, :bind)

  i = 0
  zm_reactor.periodical_timer(800) do
    i += 1
    puts i
    push.send_message(:name => 'test', :body => "Test Payload #{i}")
  end
end.start!
