require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

include VBOX

describe "VBOX::CmdLineAPI" do

  # d0   -> d1, d2, d3
  # d1   -> d1.1, d1.2, d1.3
  # d1.1 -> d1.1.1, d1.1.2, d1.1.3
  # xx   -> xx.1, xx.2, xx.3
  describe "_gen_vm_name" do
    it "should generate names from parent 'd0' -> d1, d2, d3" do
      api = CmdLineAPI.new
      api.stub! :list_vms => []
      api._gen_vm_name("d0").should == "d1"
      api.stub! :list_vms => [ VM.new(:name => 'd1') ]
      api._gen_vm_name("d0").should == "d2"
      api.stub! :list_vms => [ VM.new(:name => 'd1'), VM.new(:name => 'd2') ]
      api._gen_vm_name("d0").should == "d3"
    end

    it "should generate names from parent 'd1' -> d1.1, d1.2, d1.3" do
      api = CmdLineAPI.new
      api.stub! :list_vms => []
      api._gen_vm_name("d1").should == "d1.1"
      api.stub! :list_vms => [ VM.new(:name => 'd1.1') ]
      api._gen_vm_name("d1").should == "d1.2"
      api.stub! :list_vms => [ VM.new(:name => 'd1.1'), VM.new(:name => 'd1.2') ]
      api._gen_vm_name("d1").should == "d1.3"
    end

    it "should generate names from parent 'd1.1' -> d1.1.1, d1.1.2, d1.1.3" do
      api = CmdLineAPI.new
      api.stub! :list_vms => []
      api._gen_vm_name("d1.1").should == "d1.1.1"
      api.stub! :list_vms => [ VM.new(:name => 'd1.1.1') ]
      api._gen_vm_name("d1.1").should == "d1.1.2"
      api.stub! :list_vms => [ VM.new(:name => 'd1.1.1'), VM.new(:name => 'd1.1.2') ]
      api._gen_vm_name("d1.1").should == "d1.1.3"
    end

    it "should generate names from parent 'xx' -> xx.1, xx.2, xx.3" do
      api = CmdLineAPI.new
      api.stub! :list_vms => []
      api._gen_vm_name("xx").should == "xx.1"
      api.stub! :list_vms => [ VM.new(:name => 'xx.1') ]
      api._gen_vm_name("xx").should == "xx.2"
      api.stub! :list_vms => [ VM.new(:name => 'xx.1'), VM.new(:name => 'xx.2') ]
      api._gen_vm_name("xx").should == "xx.3"
    end
  end
end
