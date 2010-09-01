require 'dripdrop/node'
require 'sinatra/base'

ddn = DripDrop::Node.new do |node|
  #Address used to show a simple pub sub relationship
  simple_pub_sub_addr = 'tcp://127.0.0.1:2903'
   
  #Addresses for a forwarder, this aggregates multiple pub/sub to a single stream
  forwarder_in_addr   = 'tcp://127.0.0.1:2900'
  forwarder_out_addr  = 'tcp://127.0.0.1:2901'

  #Web Socket exit point 
  ws_addr = 'ws://127.0.0.1:2902'
  
  ###
  ### Listening to pub sub
  ###
  node.zmq_subscribe(simple_pub_sub_addr).on_recv do |message|
    node.send_internal(:my_rebroadcast,message)
    print '-'
  end

  ###
  ### A Pure ZMQ Forwarder
  ###
  #Receive a raw message, not yet decoded to a ruby string, fine for forwarding
  #this section acts like the tool zmq_forwarder that comes with zeromq
  forwarder_pub = node.zmq_publish(forwarder_out_addr)
  node.zmq_subscribe(forwarder_in_addr,:socket_ctype => :bind).on_recv_raw do |message|
    forwarder_pub.send_message(message)
  end

  ###
  ### Listening to the forwarder 
  ###
  node.zmq_subscribe(forwarder_out_addr).on_recv do |message|
    node.send_internal(:my_rebroadcast,message)
    print '.'
  end

  ###
  ### A Web sockets adapter
  ###
  ws_handler   = node.websocket(ws_addr)
  #Setup a websockets server
  ws_handler.on_open {|ws|
    node.recv_internal(:my_rebroadcast,ws) {|message|
      ws.send(message.to_hash.to_json)
    }
  }.on_recv {|message,ws|
    ws.send "Something's come over the socket!"
  }.on_close {|ws|
    node.remove_recv_internal(:my_rebroadcast,ws)
  }.on_error {|ws|
    node.remove_recv_internal(:my_rebroadcast,ws)
  }
end

#Let's also fire up sinatra, that you can actually view the web socket
class WebServer < Sinatra::Base
  set :logging, false
  get '/' do
    %%
      <html>
      <head>
        <title>View</title>
        <script type='text/javascript' src='http://code.jquery.com/jquery-1.4.2.min.js'></script>
        <script type='text/javascript'>
          $.messageStats = {};
          $.messageStats.count = 0;
          
          function logMessage(str) {
            $.messageStats.count++;
            var evenOdd = $.messageStats.count \% 2 == 0 ? 'even' : 'odd';
            $('#status').append('<div class="message ' + evenOdd + '">' + str + '</div>');
          };

          var ws = new WebSocket("ws://127.0.0.1:2902");
          ws.onopen = function(event) {
          };
          ws.onmessage = function(event) {
            logMessage(event.data);
          };
          ws.onerror = function(event) {
            logMessage("An error occurred");
          }
        </script>
        <style type='text/css'>
          body    {font-family: Helvetica, Arial, sans-serif}
          h1      {font-size: 25px;}
          .message {border-bottom: 1px solid silver; width: 500px;}
          .even {background-color: #f5f5f5};
        </style>
      </head>
      <body>
        <h1>A Real... Live... WebSocket!</h1>
        <div id="status">
        </div>
      </body>
      </html>
    %
  end
end
WebServer.run! :host => 'localhost', :port => 4567

#ddn.join #Would be necessary, but sinatra blocks the app for us
