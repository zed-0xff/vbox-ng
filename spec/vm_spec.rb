require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "VBOX::VM" do
  describe "all()" do
    it "returns array" do
      VBOX::VM.all.should be_instance_of(Array)
    end

    it "returns array of VBOX::VM" do
      VBOX::VM.all.map(&:class).uniq.should == [VBOX::VM]
    end
  end

  TEST_VM_NAME = "d0"
  TEST_VM_UUID = 'ae340207-f472-4d63-80e7-855fca6808cb'

  [:find, :[]].each do |method|
    describe method do
      it "finds VM by name" do
        vm = VBOX::VM.send(method, TEST_VM_NAME)
        vm.should be_instance_of(VBOX::VM)
      end

      it "finds VM by uuid" do
        vm = VBOX::VM.send(method, TEST_VM_UUID)
        vm.should be_instance_of(VBOX::VM)
      end

      it "finds VM by {uuid}" do
        vm = VBOX::VM.send(method, "{#{TEST_VM_UUID}}")
        vm.should be_instance_of(VBOX::VM)
      end
    end
  end
end
