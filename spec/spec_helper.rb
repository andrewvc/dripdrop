require File.expand_path(File.join(File.dirname(__FILE__), %w[. .. lib dripdrop]))
Thread.abort_on_exception = true

# Used to test websocket clients. 
require 'gimite-websocket'

def rand_addr(scheme='tcp')
  "#{scheme}://127.0.0.1:#{rand(10_000) + 20_000}"
end

def run_reactor(time=0.2,opts={},&block)
  ddn = DripDrop::Node.new(opts,&block)
  ddn.start
  sleep time
  ddn.stop
  sleep 0.1
  ddn
end
