require 'dripdrop/node'
require 'sinatra/base'

ddn = DripDrop::Node.new do |node|
  puts "Starting" if node.debug
  
  forwarder_sub_addr = 'tcp://127.0.0.1:2900'
  forwarder_pub_addr = 'tcp://127.0.0.1:2901'
  ws_addr = 'ws://127.0.0.1:2902'
  
  ###
  ### A Pure ZMQ Forwarder
  ###
  #Receive a raw message, not yet decoded to a ruby string, fine for forwarding
  #this section acts like the tool zmq_forwarder that comes with zeromq
  forwarder_pub = node.zmq_publish(forwarder_pub_addr)
  node.zmq_subscribe(forwarder_sub_addr,:socket_ctype => :bind).on_recv_raw do |message|
    forwarder_pub.send_message(message)
  end
  
  ###
  ### A Web sockets adapter
  ###
  ws   = node.websocket(ws_addr)
  #Setup a websockets server
  ws.on_open {|ws|
    ws.send('Sock Open')
    #Receive an internal message from somewhere within this block. This is necessary since within
    #A single process only one app can connect to a given ZMQ socket. This is likely fixable, and therefore is a bug.
    #Still, this could be a useful mechanism
    node.recv_internal(:websockets) {|message|
      ws.send(message.to_hash.to_json)
    }
  }.on_recv {|message,ws|
    ws.send "Something's come over the socket!"
  }.on_close {
    ws.send "SOCK CLOSE"
  }
  
  ###
  ### A simple listening endpoint
  ###
  node.zmq_subscribe(forwarder_pub_addr).on_recv do |message|
    node.send_internal(:websockets,message)
    print '.'
  end
  
  #To test it out, lets run some messages through
  Thread.new do
    zpub_tester = node.zmq_publish('tcp://127.0.0.1:2900', :socket_ctype => :connect)
    loop do
      zpub_tester.send_message(DripDrop::Message.new('test/message', :body => [1,2,{}]))
      sleep 2
    end
  end

end
#Let's also fire up sinatra, that way people can actually view the web socket
class WebServer < Sinatra::Base
  set :logging, false
  get '/' do
    %%
      <html>
      <head>
        <title>View</title>
        <script type='text/javascript' src='http://code.jquery.com/jquery-1.4.2.min.js'></script>
        <script type='text/javascript'>
          function logMessage(str) {
            console.log(str);
            $('#status').append('<div class="message">' + str + '</div>');
          };

          var ws = new WebSocket("ws://127.0.0.1:2902");
          ws.onopen = function(event) {
            logMessage("Socket Opened");
          };
          ws.onmessage = function(event) {
            logMessage(event.data);
          };
          ws.onerror = function(event) {
            logMessage("An error occurred");
          }
        </script>
      </head>
      <body>
        Status:
        <div id="status">
        </div>
      </body>
      </html>
    %
  end
end
puts "Starting webserver on http://localhost:4567"
WebServer.run! :host => 'localhost', :port => 4567

#ddn.join #Would be necessary, but sinatra blocks the app for us
