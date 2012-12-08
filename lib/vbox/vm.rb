module VBOX
  class VM
    attr_accessor :name, :uuid, :state

    def initialize params = {}
      @metadata = params[:metadata]
      _parse_metadata
      @name = params[:name] if params[:name]
      @uuid = params[:uuid] if params[:uuid]
    end

    private

    def _parse_metadata
      return unless @metadata && @metadata.any?
      @name  = @metadata['name']
      @uuid  = @metadata['UUID']
      @state = @metadata['VMState'].to_sym
    end

    def deep_copy x
      Marshal.load(Marshal.dump(x))
    end

    public

    def metadata
      if !@metadata || @metadata.empty?
        reload_metadata
      end
      @metadata
    end
    alias :fetch_metadata :metadata

    %w'start pause resume reset poweroff savestate acpipowerbutton acpisleepbutton destroy'.each do |action|
      define_method "#{action}!" do |*args|
        VBOX.api.send( action, uuid || name, *args )
      end
    end

    def create!
      raise "cannot create VM w/o name" if self.name.to_s == ""
      VBOX.api.createvm(self) || raise("failed to create VM")
      reload_metadata
      self
    end

    # set some variable: change VM name, memory size, pae, etc
    def set_var k, v = nil
      reload_metadata unless @metadata
      @metadata_orig ||= deep_copy(@metadata)

      if k.is_a?(Hash) && v.nil?
        k.each do |kk,vv|
          @metadata[kk.to_s] = vv.to_s
        end
      elsif !k.is_a?(Hash) && !v.is_a?(Hash)
        @metadata[k.to_s] = v.to_s
      else
        raise "invalid params combination"
      end
    end
    alias :set_vars :set_var

    # save modified metadata, if any
    def save
      return nil if @metadata == @metadata_orig
      vars = {}
      @metadata.each do |k,v|
        vars[k] = v if @metadata[k].to_s != @metadata_orig[k].to_s
      end
      VBOX.api.modify self, vars
    end

    # reload all VM metadata info from VirtualBox
    def reload_metadata
      raise "cannot reload metadata if name & uuid are NULL" unless name || uuid
      @metadata = VBOX.api.get_vm_details(self)

      # make a 'deep copy' of @metadata to detect changed vars
      # dup() or clone() does not fit here b/c they leave hash values linked to each other
      @metadata_orig = deep_copy(@metadata)
      _parse_metadata
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
          return nil unless v=metadata['CfgFile']
          dir = File.dirname(v)
          `du -sm "#{dir}"`.split("\t").first.tr("M","").to_i
        end
    end

    def memory_size
      metadata['memory'].to_i
    end

    def snapshots
      VBOX.api.get_snapshots(uuid||name)
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
        r ? VM.new(:metadata => r) : nil
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

      def create! *args
        new(*args).create!
      end

    end
  end
end
