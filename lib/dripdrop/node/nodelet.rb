class DripDrop::Node
  # See the documentation for +nodelet+ in DripDrop::Node
  class Nodelet
    attr_accessor :name, :routing
    
    def initialize(name, routes)
      @name    = name
      @routing = {}
      routes.each do |route_name,handler|
        # Copy the original routing table
        route route_name, handler
      
        # Define short versions of the local routes for
        # this nodelet's routing table
        if (route_name.to_s =~ /^#{name}_(.+)$/)
          short_name = $1
          route short_name, handler
        end
      end
    end
    
    def route(name,handler)
      @routing[name] = handler
      (class << self; self; end).class_eval do
        define_method(name) { handler }
      end
    end
  end
end
