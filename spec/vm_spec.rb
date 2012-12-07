require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

TEST_VM_NAME = "vbox-ng-test-vm"
TEST_VM_UUID = 'ae340307-f472-4d63-80e7-855fca6808cb'

TEST_VM_NAME2 = "vbox-ng-test-vm2"
TEST_VM_UUID2 = 'ae340307-f472-4d63-80e7-855fca6808cc'

describe "VBOX::VM" do
  before :all do
    vm = VBOX::VM.find TEST_VM_NAME
    vm.destroy!.should(be_true) if vm

    vm = VBOX::VM.create! :name => TEST_VM_NAME, :uuid => TEST_VM_UUID
    vm.should be_instance_of(VBOX::VM)
  end

  after :all do
    vm = VBOX::VM.find TEST_VM_NAME
    vm.destroy!.should(be_true) if vm
  end

  describe "all()" do
    it "returns array" do
      VBOX::VM.all.should be_instance_of(Array)
    end

    it "returns array of VBOX::VM" do
      VBOX::VM.all.map(&:class).uniq.should == [VBOX::VM]
    end
  end

  describe :first do
    it "returns VBOX::VM" do
      VBOX::VM.first.should be_instance_of(VBOX::VM)
    end
  end

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

      it "finds nothing" do
        vm = VBOX::VM.send(method, "blah-blah-blah-unexistant-vm-#{rand}-#{rand}-#{rand}")
        vm.should be_nil
      end
    end
  end

  describe :dir_size do
    VBOX::VM.first.dir_size.should > 0
  end

  %w'start pause resume reset poweroff savestate acpipowerbutton acpisleepbutton destroy clone'.each do |action|
    action << "!"
    describe action do
      it "should respond to #{action}" do
        VBOX::VM.first.should respond_to(action)
      end
    end
  end

  describe :expand_glob do
    def _glob2arr glob
      r = []
      VBOX::VM.expand_glob(glob){ |x| r << x }
      r
    end

    {
      'xxx'                  => ['xxx'],
      'xx*'                  => ['xx*'],
      'a{1-2}'               => ['a1', 'a2'],
      '{0-11}b'              => (0..11).map{ |x| "#{x}b" },
      'a{0-999}b'            => (0..999).map{ |x| "a#{x}b" },
      '{1-10}.{1-10}.{1-10}' => (0..999).map{ |x| ("%03i" % x).split('').join('.').gsub('0','10') }
    }.each do |k,v|
      it "should expand #{k.inspect}" do
        _glob2arr(k).sort.should == v.sort
      end
    end
  end

  describe :create do
    before(:all) do
      vm = VBOX::VM.find TEST_VM_NAME2
      vm.destroy!.should(be_true) if vm
    end

    it "should create VM" do
      vm = VBOX::VM.new :name => TEST_VM_NAME2
      Array(vm.metadata).should be_empty
      vm = vm.create!
      vm.should be_instance_of(VBOX::VM)
      vm.metadata.size.should > 10
      vm.reload_metadata
      vm.name.should == TEST_VM_NAME2
    end
  end
end
