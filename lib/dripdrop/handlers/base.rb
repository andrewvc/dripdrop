class DripDrop
  class BaseHandler
    
    def on_error(&block)
      @err_cbak = block
    end

    def handle_error(exception,*extra)
      if @err_cbak
        begin
          @err_cbak.call(exception,*extra)
        rescue StandardError => e
          print_exception(e)
        end
      else
        print_exception(exception)
      end
    end

    def print_exception(exception)
      if exception.is_a?(Exception)
        $stderr.write exception.message
        $stderr.write exception.backtrace.join("\t\n")
      else
        $stderr.write "Expected an exception, got: #{exception.inspect}"
      end
    end
     
    private
    # Normalize Hash objs and DripDrop::Message objs into DripDrop::Message objs
    def dd_messagify(message,klass=DripDrop::Message)
      if message.is_a?(Hash)
        return klass.from_hash(message)
      elsif message.is_a?(DripDrop::Message)
        return message
      else
        return message
      end
    end

  end
end
