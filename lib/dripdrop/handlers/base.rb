class DripDrop
  class BaseHandler
    
    def on_error(&block)
      @err_cbak = block
    end

    def handle_error(exception)
      if @err_cbak
        @err_cbak.call(exception)
      else
        $stderr.write exception.message
        $stderr.write exception.backtrace.join("\t\n")
      end
    end
     
    private
    # Normalize Hash objs and DripDrop::Message objs into DripDrop::Message objs
    def dd_messagify(message)
      if message.is_a?(Hash)
        return DripDrop::Message.new(message[:name], :head => message[:head],
                                                     :body => message[:body])
      elsif message.is_a?(DripDrop::Message)
        return message
      else
        return message
      end
    end

  end
end
