require 'rubygems'
require 'rack'
require 'sinatra'
require 'dripdrop/agent'

FORWARDER_IN   = 'tcp://127.0.0.1:2700'
WEBSOCKET_ADDR = 'ws://127.0.0.1:2702'

module Rack
  class DripDropStats
    def initialize(app, name = nil)
      @app    = app
      @agent  = DripDrop::Agent.new(FORWARDER_IN)
    end
    def call(env)
      start = Time.now
      status, headers, body = @app.call(env)
      
      runtime = Time.now - start
      
      serializable_env = {}
      env.each {|k,v|
        serializable_env[k] = v if v.is_a?(String) || v.is_a?(Numeric)
      }
      message_body = {
        'runtime' => runtime,
        'env'     => serializable_env
      }
      begin
        @agent.send_message('rack/stats', message_body)
      rescue StandardError => e
        raise e.inspect
      end

      [status, headers, body]
    end
  end
end
use Rack::DripDropStats

set :env, :production
disable :run

get '/' do
  'A sample ruby/rack application'
end

get '/ws' do
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

        var ws = new WebSocket('#{WEBSOCKET_ADDR}');
        ws.onopen = function(event) {
        };
        ws.onmessage = function(event) {
          var data = $.parseJSON(event.data);
          var browser = data.body.env.HTTP_USER_AGENT.substr(0,20);
          var path    = data.body.env.REQUEST_PATH;
          var addr    = data.body.env.REMOTE_ADDR;
          var runtime = data.body.runtime;
          logMessage(runtime + ' Secs> ' + browser + ' - ' + path + ' - ' + addr);
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

run Sinatra::Application
