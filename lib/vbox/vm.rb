module VBOX
  class VM
    attr_accessor :name, :uuid, :memory_size, :dir_size, :state, :all_vars

    def initialize
      @all_vars = {}
    end

    %w'start pause resume reset poweroff savestate acpipowerbutton acpisleepbutton destroy'.each do |action|
      define_method "#{action}!" do
        VBOX.api.send( action, uuid || name )
      end
    end

    def clone! params
      raise "argument must be a Hash" unless params.is_a?(Hash)
      raise "no :snapshot key" unless params[:snapshot]
      r = VBOX.api.clone self.name, params
      case r
      when Array
        if r.first.is_a?(VM)
          r
        else
          r.map{ |name| VM.find(name) }
        end
      when String
        VM.find(r)
      when nil
        nil
      else
        r
      end
    end

    def dir_size
      @dir_size ||=
        begin
          VBOX.api.get_vm_details(self) unless @all_vars['CfgFile']
          return nil unless v=@all_vars['CfgFile']
          dir = File.dirname(v.tr('"',''))
          `du -sm "#{dir}"`.split("\t").first.tr("M","").to_i
        end
    end

    class << self
      def all
        VBOX.api.list_vms
      end

      def first
        all.first
      end

      def find name_or_uuid
        VBOX.api.get_vm_details name_or_uuid
      end

      alias :[] :find
    end
  end
end
