module VBOX
  class VM
    attr_accessor :name, :uuid, :memory_size, :dir_size, :state

    class << self
      def all
        VBOX.api.list_vms
      end
    end
  end
end
