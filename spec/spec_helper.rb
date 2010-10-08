require File.expand_path(File.join(File.dirname(__FILE__), %w[.. lib dripdrop]))

def rand_addr
  "tcp://127.0.0.1:#{rand(10_1000) + 20_000}"
end
