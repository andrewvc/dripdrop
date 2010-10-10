require 'dripdrop/node'
Thread.abort_on_exception = true

#Define our handlers
DripDrop::Node.new do
  z_addr = 'tcp://127.0.0.1:2200'
    
  #Create a publisher
  pub = zmq_publish(z_addr,:bind)

  #Create three subscribers
  sub1 = zmq_subscribe(z_addr,:connect)

  sub1.on_recv do |message|
    puts "Receiver 1 #{message.inspect}"
  end

  sub1.topic_filter = /[13579]$/

  sub2 = zmq_subscribe(z_addr,:connect)

  sub2.on_recv do |message|
    puts "Receiver 2 #{message.inspect}"
  end

  sub2.topic_filter = /[02468]$/

  zmq_subscribe(z_addr, :connect).on_recv do |message|
    puts "Receiver 3 #{message.inspect}"
  end
  
  zm_reactor.periodical_timer(5) do
    #Sending a hash as a message implicitly transforms it into a DripDrop::Message
    pub.send_message(:name => Time.now.to_i.to_s, :body => 'Test Payload')
  end
end.start! #Start the reactor and block until complete
