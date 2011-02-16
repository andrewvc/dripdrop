class DripDrop
  class HTTPClientHandler < BaseHandler
    attr_reader :address, :opts
    
    def initialize(uri, opts={})
      @uri     = uri
      @address = @uri.to_s
      @opts    = opts
      @message_class = @opts[:message_class] || DripDrop.default_message_class
    end
    
    def send_message(message,&block)
      dd_message = dd_messagify(message)
      if dd_message.is_a?(DripDrop::Message)
        uri_path = @uri.path.empty? ? '/' : @uri.path
        
        req = EM::Protocols::HttpClient.request(
          :host => @uri.host, :port => @uri.port,
          :request => uri_path, :verb => 'POST',
          :contenttype => 'application/json',
          :content => dd_message.encode_json
        )
        req.callback do |response|
          begin
            # Hack to fix evma http
            response[:content] =~ /(\{.*\})/ 
            fixed_body = $1
            block.call(@message_class.decode(fixed_body)) if block
          rescue StandardError => e
            handle_error(e)
          end
        end
      else
        raise "Unsupported message type '#{dd_message.class}'"
      end
    end
  end
end
