require 'spec_helper'

describe "routing" do
  shared_examples_for "all routing" do
    it "should define all routes in the table" do
      @expected_routing.keys.each do |route_name|
        @node.routing.keys.should include(route_name)
      end
    end
    
    it "should define a handler in the routing table for each route" do
      @expected_routing.keys.each do |route_name|
        @node.routing[route_name].should be_kind_of(DripDrop::BaseHandler)
      end
    end    

    it "should define a singleton method for each entry in the routing table" do
      @expected_routing.keys.each do |route_name|
        @node.send(route_name).should == @node.routing[route_name]
      end
    end

    it "should create handlers with the correct properties" do
      @expected_routing.each do |route_name,expected_props|
        handler = @node.send(route_name)
        handler.class.should == expected_props[:class]
        handler.socket_ctype.should == expected_props[:socket_ctype]
      end
    end
  end
  
  context "with no groups" do
    before(:all) do
      @expected_routing = {
        :distributor => {:class => DripDrop::ZMQPushHandler, :socket_ctype => :bind},
        :worker1     => {:class => DripDrop::ZMQPullHandler, :socket_ctype => :connect},
        :worker2     => {:class => DripDrop::ZMQPullHandler, :socket_ctype => :connect}
      }
      @node = run_reactor do
        route :distributor, :zmq_push, rand_addr, :bind
        route :worker1,     :zmq_pull, distributor.address, :connect
        route :worker2,     :zmq_pull, distributor.address, :connect
      end
    end

    it_should_behave_like "all routing"
  end
  context "with groups" do
    before(:all) do
      @expected_routing = {
        :distributor_output     => {:class => DripDrop::ZMQPushHandler, :socket_ctype => :bind},
        :worker_cluster_worker1 => {:class => DripDrop::ZMQPullHandler, :socket_ctype => :connect},
        :worker_cluster_worker2 => {:class => DripDrop::ZMQPullHandler, :socket_ctype => :connect}
      }
      @node = run_reactor do
        routes_for :distributor do
          route :output, :zmq_push, rand_addr, :bind
        end
        routes_for :worker_cluster do
          route :worker1,     :zmq_pull, distributor_output.address, :connect
          route :worker2,     :zmq_pull, distributor_output.address, :connect
        end
      end
    end
    
    it_should_behave_like "all routing"
  end
end
