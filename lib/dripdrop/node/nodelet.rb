class DripDrop::Node
  # See the documentation for +nodelet+ in DripDrop::Node
  class Nodelet
    attr_accessor :name, :routing
    
    def initialize(ctx, name, routes)
      @ctx              = ctx
      @name             = name
      @internal_routing = {}
    end
    
    def route(name,handler_type,*handler_args)
      handler = @ctx.route_full(self, name, handler_type, *handler_args)
      @internal_routing[name] = handler
       
      (class << self; self; end).class_eval do
        define_method(name) { handler }
      end
    end

    # Check for the method as a route in @ctx, if found
    # memoize it by defining it as a singleton
    def method_missing(meth,*args)
      (class << self; self; end).class_eval do
        define_method(meth) { @ctx.send(meth,*args) }
      end
      self.send(meth,*args)
    end
  end
end
