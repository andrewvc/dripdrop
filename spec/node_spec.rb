require 'spec_helper'

describe DripDrop::Node do
  shared_examples_for "all initialization methods" do
    it "should start EventMachine" do
      EM.reactor_running?.should be_true
    end
    
    it "should start ZMQMachine" do
      pending "This is not repeatedly reliable"
      @ddn.zm_reactor.running?.should be_true
    end
    
    it "should run the block" do
      @reactor_ran.should be_true
    end
  end
 
  #These tests break all subsequent ones,
  #so require a special flag to test them
  if ENV['DRIPDROP_INITSPEC'] == 'true'
    describe "initialization with a block" do
      before(:all) do
        reactor_ran = false
        @ddn = DripDrop::Node.new do
          reactor_ran = true
        end
        @ddn.start
        sleep 1
          
        @reactor_ran = reactor_ran
      end
      
      it_should_behave_like "all initialization methods"
    end

    describe "initialization as a class" do
      before(:all) do
        class InitializationTest < DripDrop::Node
          attr_accessor :reactor_ran
          def action
            @reactor_ran = true
          end
        end
        
        @ddn = InitializationTest.new
        @ddn.start
        sleep 1
          
        @reactor_ran = @ddn.reactor_ran 
      end
      
      it_should_behave_like "all initialization methods"
    end
  end
   

  describe "shutdown" do
    before do
      @ddn = DripDrop::Node.new {
        zmq_subscribe(rand_addr,:bind) #Keeps ZMQMachine Happy
      }
      @ddn.start
      sleep 0.1
      @ddn.stop rescue nil
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
