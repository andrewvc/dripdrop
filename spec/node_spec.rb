require 'spec_helper'

describe DripDrop::Node do
  describe "initialization" do
    before do
      @ddn = DripDrop::Node.new {}
      @ddn.start
      sleep 0.1
    end
    
    it "should start EventMachine" do
      EM.reactor_running?.should be_true
    end
    
    it "should start ZMQMachine" do
      @ddn.zm_reactor.running?.should be_true
    end
    
    after do
      @ddn.stop rescue nil
    end
  end

  describe "shutdown" do
    before do
      @ddn = DripDrop::Node.new {}
      @ddn.start
      sleep 0.1 
      @ddn.stop
      sleep 0.1
    end
  
    it "should stop EventMachine" do
      EM.reactor_running?.should be_false
    end
    
    it "should stop ZMQMachine" do
      @ddn.zm_reactor.running?.should be_false
    end
  end
end
