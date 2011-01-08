class DripDrop
  class UnixDomainHandler < BaseHandler
    class EMHandler < EM::Connection
      def initialize(handler)
        @handler = handler
      end
      
      def receive_data(data)
        puts "D: #{data.inspect}"
        @handler.recv_data(DripDrop::Message.decode(data))
      end
    end
    
    def initialize(path, bind_or_connect, opts={})
      if bind_or_connect == :bind
        File.unlink(path) if File.exists?(path) && File.socket?(path)
        @conn = EM.start_unix_domain_server(path, EMHandler, self)
      elsif bind_or_connect == :connect
        @conn = EM.connect_unix_domain(path, EMHandler, self)
      else
        raise ArgumentError, "Expected bind or connect, not '#{bind_or_connect}'"
      end
    end

    def on_recv(&block)
      @on_recv_handler = block
    end
  
    def send_message(message)
      @conn.send_data dd_messagify(message).encoded
    end
    
    def recv_data(data)
      @on_recv_handler.call(data) if @on_recv_handler
    end
  end
end
