require 'dripdrop/node'
Thread.abort_on_exception = true

#Define our handlers
DripDrop::Node.new do
  z_addr = 'tcp://127.0.0.1:2200'
    
  #Create a publisher
  pub = zmq_publish(z_addr,:bind)

  #Create two subscribers
  zmq_subscribe(z_addr,:connect).on_recv do |message|
    puts "Receiver 1 #{message.inspect}"
  end
  zmq_subscribe(z_addr, :connect).on_recv do |message|
    puts "Receiver 2 #{message.inspect}"
  end
  
  zm_reactor.periodical_timer(5) do
    #Sending a hash as a message implicitly transforms it into a DripDrop::Message
    pub.send_message(:name => 'test', :body => 'Test Payload')
  end
end.start! #Start the reactor and block until complete
