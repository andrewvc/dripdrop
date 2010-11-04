require 'thin'
require 'json'

class DripDrop
  class HTTPDeferrableBody < BaseHandler
    include EventMachine::Deferrable
    
    def call(body)
      body.each do |chunk|
        @body_callback.call(chunk)
      end
    end

    def each(&blk)
      @body_callback = blk
    end
    
    def send_message(raw_msg)
      msg = dd_messagify(raw_msg)
      if msg.class == DripDrop::Message
        json = msg.encode_json
        self.call([json])
        self.succeed
      else
        raise "Message Type '#{msg.class}' not supported"
      end
    end
  end
  
  class HTTPApp
    
    AsyncResponse = [-1, {}, []].freeze
    
    def initialize(msg_format,&block)
      @msg_format = msg_format
      @recv_cbak  = block
    end
    
    def call(env)
      body = HTTPDeferrableBody.new
      
      EM.next_tick do
        env['async.callback'].call([200, {'Content-Type' => 'text/plain', 'Access-Control-Allow-Origin' => '*'}, body])
        EM.next_tick do
          case @msg_format
          when :dripdrop_json
            msg = DripDrop::Message.decode_json(env['rack.input'].read)
            @recv_cbak.call(msg,body,env)
          else
            raise "Unsupported message type #{@msg_format}"
          end
        end
      end
       
      AsyncResponse
    end
  end
  
  class HTTPServerHandler < BaseHandler
    attr_reader :address, :opts
    
    def initialize(uri,opts={})
      @uri     = uri
      @address = uri.to_s
      @opts    = opts
    end
    
    def on_recv(msg_format=:dripdrop_json,&block)
      #Thin's error handling only rescues stuff w/o a backtrace
      begin
        Thin::Logging.silent = true
         
        Thin::Server.start(@uri.host, @uri.port) do
          map '/' do
            run HTTPApp.new(msg_format,&block)
          end
        end
      rescue Exception => e
        puts "Error in Thin server: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end
  end

  class HTTPClientHandler < BaseHandler
    attr_reader :address, :opts
    
    def initialize(uri, opts={})
      @uri     = uri
      @address = @uri.to_s
      @opts    = opts
    end
    
    def send_message(msg,&block)
      if msg.class == DripDrop::Message
        req = EM::Protocols::HttpClient.request(
          :host => @uri.host, :port => @uri.port,
          :request => '/', :verb => 'POST',
          :contenttype => 'application/json',
          :content => msg.encode_json
        )
        req.callback do |response|
          block.call(DripDrop::Message.decode_json(response[:content]))
        end
      else
        raise "Unsupported message type '#{msg.class}'"
      end
    end
  end
end
