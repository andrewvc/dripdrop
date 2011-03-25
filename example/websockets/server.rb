require 'rubygems'
require 'dripdrop'

class MyApp < DripDrop::Node

  def action
    route :my_server,  :websocket_server, 'ws://127.0.0.1:9292'
    my_server.on_open do |my_client|
      EM::PeriodicTimer.new(1) do
        my_client.send_message(:name => 'time_request', :body => Time.now.to_s)
      end
    end
  end
end

MyApp.new.start!
