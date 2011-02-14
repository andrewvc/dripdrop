class DripDrop
  class BaseHandler
    
    def on_error(&block)
      @err_cbak = block
    end

    def handle_error(exception)
      if @err_cbak
        begin
          @err_cbak.call(exception)
        rescue StandardError => e
          print_exception(e)
        end
      else
        print_exception(e)
      end
    end

    def print_exception(exception)
      $stderr.write exception.message
      $stderr.write exception.backtrace.join("\t\n")
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
