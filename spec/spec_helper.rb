require File.expand_path(File.join(File.dirname(__FILE__), %w[.. lib dripdrop]))
Thread.abort_on_exception = true

def rand_addr
  "tcp://127.0.0.1:#{rand(10_000) + 20_000}"
end
