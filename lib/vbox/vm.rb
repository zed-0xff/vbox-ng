module VBOX
  class VM
    attr_accessor :name, :uuid, :memory_size, :dir_size, :state, :all_vars

    def initialize
      @all_vars = {}
    end

    def dir_size
      @dir_size ||=
        begin
          VBOX.api.get_vm_details(self) unless @all_vars['CfgFile']
          return nil unless v=@all_vars['CfgFile']
          dir = File.dirname(v.tr('"',''))
          `du -s -BM "#{dir}"`.split("\t").first.tr("M","")
        end
    end

    class << self
      def all
        VBOX.api.list_vms
      end

      def find name_or_uuid
        VBOX.api.get_vm_details name_or_uuid
      end

      alias :[] :find
    end
  end
end
