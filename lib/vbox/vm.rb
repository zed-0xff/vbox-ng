module VBOX
  class VM
    attr_accessor :name, :uuid, :state

    def initialize params = {}
      @all_vars = params[:all_vars]
      _parse_all_vars
      @name = params[:name] if params[:name]
      @uuid = params[:uuid] if params[:uuid]
    end

    private

    def _parse_all_vars
      return unless @all_vars && @all_vars.any?
      @name  = @all_vars['name'].strip.sub(/^"/,'').sub(/"$/,'')
      @uuid  = @all_vars['UUID'].strip.sub(/^"/,'').sub(/"$/,'')
      @state = @all_vars['VMState'].tr('"','').to_sym
    end

    public

    def all_vars
      if !@all_vars || @all_vars.empty?
        @all_vars = VBOX.api.get_vm_details(self)
        _parse_all_vars
      end
      @all_vars
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
          return nil unless v=all_vars['CfgFile']
          dir = File.dirname(v.tr('"',''))
          `du -sm "#{dir}"`.split("\t").first.tr("M","").to_i
        end
    end

    def memory_size
      all_vars['memory'].to_i
    end

    class << self
      def all
        VBOX.api.list_vms :include_state => true
      end

      def first
        all.first
      end

      def find name_or_uuid
        r = VBOX.api.get_vm_details name_or_uuid
        r ? VM.new(:all_vars => r) : nil
      end
      alias :[] :find

      def find_all glob
        all.keep_if do |vm|
          expand_glob(glob){ |glob1| File.fnmatch(glob1, vm.name) }
        end
      end

      # expand globs like "d{1-30}" to d1,d2,d3,d4,...,d29,d30
      def expand_glob glob, &block
        if glob[/\{(\d+)-(\d+)\}/]
          $1.to_i.upto($2.to_i) do |i|
            expand_glob glob.sub($&,i.to_s), &block
          end
        else
          yield glob
        end
      end

    end
  end
end
