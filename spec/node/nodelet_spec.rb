require 'spec_helper'

describe "nodelets" do
  class SpecialNodelet < DripDrop::Node::Nodelet
    def action
      route :worker1,     :zmq_pull, distributor_output.address, :connect
      route :worker2,     :zmq_pull, distributor_output.address, :connect
    end
  end
  
  before(:all) do
    nodelets = {}
    
    
    @node = run_reactor do
      nodelet :distributor do |nlet|
        nlet.route :output, :zmq_push, rand_addr, :bind
      end
      
      nodelet :worker_cluster, SpecialNodelet
    end
    
    @nodelets = @node.nodelets
  end
  
  it "should create the nodelets" do
    @nodelets.length.should == 2
  end
  
  it "should pass a DripDrop::Node::Nodelet to the block" do
    @nodelets.values.each do |nlet|
      nlet.should be_kind_of(DripDrop::Node::Nodelet)
    end
  end
    
  it "should give access to the full routing table to nodelets" do
    @node.routing.each do |route_name,handler|
      @nodelets.values.each do |nlet|
        nlet.send(route_name).should == handler
      end
    end
  end
  
  it "should use the class SpecialNodelet for the nodelet assigned that" do
    @nodelets[:worker_cluster].should be_a(SpecialNodelet)
  end

  it "should return a DripDrop::Handler for short routes" do
    @nodelets[:distributor].send(:output).should be_a(DripDrop::BaseHandler)
  end

  it "should return a DripDrop::Handler for long routes" do
    @nodelets[:distributor].send(:distributor_output).should be_a(DripDrop::BaseHandler)
  end
  
  it "should define prefix-less versions of nodelet specific routes" do
    {
      @nodelets[:worker_cluster] => {:worker1 => :worker_cluster_worker1, 
                                     :worker2 => :worker_cluster_worker2},
      @nodelets[:distributor]    => {:output  => :distributor_output}
    }.each do |nlet, mapping|
      mapping.each do |short,long|
        nlet.send(short).should == nlet.send(long)
      end
    end
  end
end
