require 'evma_httpserver'

class DripDrop
  class HTTPServerHandlerResponse < BaseHandler
    attr_reader :em_response, :message_class
    def initialize(em_response)
      @em_response   = em_response
    end

    def send_message(message)
      message = dd_messagify(message)
      @em_response.status = 200
      @em_response.content      = message.json_encoded
      @em_response.send_response
    end
  end
   
  class HTTPEMServer < EM::Connection
    include EM::HttpServer
    
    def initialize(dd_handler)
      @dd_handler = dd_handler
    end
     
    def post_init
      super
      no_environment_strings
    end
    
    def process_http_request
      begin
        message     = @dd_handler.message_class.decode_json(@http_post_content)
        response    = EM::DelegatedHttpResponse.new(self)
        dd_response = HTTPServerHandlerResponse.new(response)
        @dd_handler.recv_cbak.call(message, dd_response) if @dd_handler.recv_cbak
      rescue StandardError => e
        handler_error(e)
      end
    end
  end

  class HTTPServerHandler < BaseHandler
    attr_reader :address, :opts, :message_class, :uri, :recv_cbak
    
    def initialize(uri,opts={})
      @uri      = uri
      @uri_path = @uri.path.empty? ? '/' : @uri.path
      @address  = uri.to_s
      @opts     = opts
      @message_class = @opts[:message_class] || DripDrop.default_message_class
    end
    
    def on_receive(msg_format=:dripdrop_json,&block)
      @recv_cbak = block
      @conn = EM.start_server(@uri.host, @uri.port, HTTPEMServer, self)
      self
    end

    def on_recv(*args,&block)
      $stderr.write "DripDrop Warning :on_recv is deprecated in favor of :on_receive"
      on_receive(*args,&block)
    end
  end
end
