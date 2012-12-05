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
end
