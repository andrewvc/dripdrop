require 'dripdrop/node'
Thread.abort_on_exception = true

DripDrop::Node.new do |node|
  addr = 'http://127.0.0.1:2200'
  
  i = 0 
  node.http_server(addr).on_recv do |response,msg|
    i += 1
    msg = DripDrop::Message.new('http/status', :body => "Success #{i}")
    response.send_message(msg)
  end
end
