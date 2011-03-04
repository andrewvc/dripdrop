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
      @ddn = DripDrop::Node.new {}
      @ddn.start
      sleep 0.1
      @ddn.stop rescue nil
      sleep 0.1
    end
  
    it "should stop EventMachine" do
      EM.reactor_running?.should be_false
    end
  end

  describe "exceptions in EM reactor" do
    class TestException < StandardError; end
     
    it "should rescue exceptions in the EM reactor" do
      pending "Not sure why em-java doesn't support this" if RUBY_PLATFORM == 'java'
      expectations = an_instance_of(TestException)
      reactor = run_reactor do
        self.class.should_receive(:error_handler).with(expectations)
        EM.next_tick do
          raise TestException, "foo"
        end
      end
    end
  end
end
