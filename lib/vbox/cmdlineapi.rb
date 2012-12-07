#!/usr/bin/env ruby
require 'awesome_print'
#require 'shellwords'
require 'open3'

module VBOX

  COMMANDS = %w'start pause resume reset poweroff savestate acpipowerbutton acpisleepbutton clone delete show'

  Snapshot = Struct.new :name, :uuid

  class CmdLineAPI
    attr_accessor :options

    def initialize options={}
      @options = options
      @options[:verbose] ||= 2 if @options[:dry_run]
      @options[:verbose] ||= 0
    end

    private
    def vboxmanage *args
      args = args.map do |arg|
        case arg
        when Hash
          arg.map{ |k,v| ["--#{k}", v == '' ? nil : v.to_s] }
        else
          arg.to_s
        end
      end.flatten.compact

      puts "[.] VBoxManage #{args.join(' ')}".gray if @options[:verbose] >= 2
      exit if @options[:dry_run]

      stdout = stderr = nil
      Open3.popen3("VBoxManage", *args.map(&:to_s)) do |i,o,e|
        i.close
        stdout = o.read
        stderr = e.read
      end

      if @options[:verbose] > 3
        STDERR.puts(stderr.strip.red)
        puts(stdout.strip) if @options[:verbose] > 4
      end

      stdout
    end

#    # run as in backtick operator, and return result
#    def ` cmd
#      puts "[.] #{cmd}".gray if @options[:verbose] >= 2
#      exit if @options[:dry_run]
#      r = super
#      #exit 1 unless $?.success?
#      r
#    end
#
#    # run as in system() call
#    def system *args
#      puts "[.] #{args.inspect}".gray if @options[:verbose] >= 2
#      exit if @options[:dry_run]
#      r = super
#      #exit 1 unless $?.success?
#      r
#    end

    public
    def get_vm_details vm_or_name_or_uuid
      name_or_uuid = case vm_or_name_or_uuid
        when String
          vm = VM.new
          vm_or_name_or_uuid
        when VM
          vm = vm_or_name_or_uuid
          vm.uuid || vm.name
        end

      h = {}
      data = vboxmanage :showvminfo, name_or_uuid, "--machinereadable"
      data.each_line do |line|
        k,v = line.strip.split('=',2)
        next unless v
        h[k] = v
      end
      h.empty? ? nil : h
    end

    def createvm vm
      options = { :name => vm.name, :register => '' }
      options[:uuid] = vm.uuid if vm.uuid
      a = vboxmanage :createvm, options
      $?.success?
    end

    # for natural string sort order
    # http://stackoverflow.com/questions/4078906/is-there-a-natural-sort-by-method-for-ruby
    def _naturalize s
      s.scan(/[^\d]+|\d+/).collect { |f| f.match(/\d+/) ? f.to_i : f }
    end

    def list_vms params = {}
      vms = []
      vboxmanage(:list, :vms).strip.each_line do |line|
        if line[UUID_RE]
          vm = VM.new
          vm.uuid = $&
          vm.name = line.gsub($&, '').strip.sub(/^"/,'').sub(/"$/,'')
          vms << vm
        end
      end
      if params[:include_state]
        # second pass
        h = Hash[*vms.map{ |vm| [vm.uuid, vm] }.flatten]
        uuid = nil # declare variable for inner loop
        vboxmanage(:list, :runningvms).strip.each_line do |line|
          h[uuid].state = :running if (uuid=line[UUID_RE]) && h[uuid]
        end
      end
      vms.sort_by{ |vm| _naturalize(vm.name) }
    end

    def get_vm_info name
      h = {}
      vboxmanage(:showvminfo, name, "--machinereadable").each_line do |line|
        line.strip!
        k,v = line.split('=',2)
        h[k] = v
      end
      h
    end

    def show name
      get_vm_info(name).each do |k,v|
        next if ['"none"', '"off"', '""'].include?(v)
        puts "#{k}=#{v}"
      end
    end

    COMMANDS.each do |cmd|
      unless method_defined?(cmd.to_sym)
        define_method(cmd) do |name|
          vboxmanage :controlvm, name, cmd
        end
      end
    end

    def start name
      if ENV['DISPLAY'] && !@options[:headless]
        vboxmanage :startvm, name
      else
        puts "[.] $DISPLAY is not set, assuming --headless".gray unless @options[:headless]
        @options[:headless] = true
        vboxmanage :startvm, name, :type => :headless
      end
    end


    def get_snapshots _name
      r = []
      name = uuid = nil
      vboxmanage(:snapshot, _name, 'list', '--machinereadable').strip.each_line do |line|
        k,v = line.strip.split('=',2)
        next unless v
        v = v.strip.sub(/^"/,'').sub(/"$/,'')
        case k
        when /SnapshotName/
          name = v
        when /SnapshotUUID/
          uuid = v
        end
        if name && uuid
          r << Snapshot.new(name, uuid)
          name = uuid = nil
        end
      end
      r
    end

    # d0   -> d1, d2, d3
    # d1   -> d1.1, d1.2, d1.3
    # d1.1 -> d1.1.1, d1.1.2, d1.1.3
    def _gen_vm_name parent_name
      # try to guess new name
      numbers = parent_name.scan /\d+/
      if numbers.any?
        lastnum = numbers.last
        names = list_vms.map(&:name)
        if lastnum.to_i == 0
          # d0 -> d1, d2, d3
          newnum = lastnum.to_i + 1
          while true
            newname = parent_name.dup
            newname[parent_name.rindex(lastnum),lastnum.size] = newnum.to_s
            return newname unless names.include?(newname)
            newnum += 1
          end
        else
          # d1   -> d1.1, d1.2, d1.3
          # d1.1 -> d1.1.1, d1.1.2, d1.1.3
          newnum = 1
          while true
            newname = "#{parent_name}.#{newnum}"
            return newname unless names.include?(newname)
            newnum += 1
          end
        end
      end
      nil
    end

    def take_snapshot vm_name, params = {}
      vboxmanage "snapshot", vm_name, "take", params[:name] || "noname"
      exit 1 unless $?.success?
      get_snapshots(vm_name).last
    end

    def _name2macpart name
      r = name.scan(/\d+/).map{ |x| "%02x" % x }.join
      r == '' ? nil : r
    end

    def clone old_vm_name, params = {}
      @clone_use_snapshot = nil
      params = @options.merge(params)
      n = params[:clones] || 1
      if n > 1
        # return array of clones
        n.times.map{ _clone(old_vm_name, params) }
      elsif n == 1
        # return one clone
        _clone(old_vm_name, params)
      else
        raise "invalid count of clones = #{n.inspect}"
      end
    end

    def _clone old_vm_name, params
      args = {}
      if new_vm_name = params['name'] || _gen_vm_name(old_vm_name)
        args[:name] = new_vm_name
      end

      snapshot = @clone_use_snapshot ||= case params[:snapshot].to_s
        when 'new', 'take', 'make'
          take_snapshot(old_vm_name, new_vm_name ? {:name => "for #{new_vm_name}"} : {})
        when 'last'
          get_snapshots(old_vm_name).last
        else
          puts "[!] please gimme --snapshot=LAST OR --snapshot=NEW option"
          exit 1
        end
      unless snapshot
        puts "[!] failed to get snapshot, cannot continue".red
        exit 1
      end

      args[:options]  = :link
      args[:register] = ''
      args[:snapshot] = snapshot.uuid

      vboxmanage :clonevm, old_vm_name, args
      return false unless $?.success?

      get_vm_info(old_vm_name).each do |k,v|
        if k =~ /^macaddress/
          old_mac = v.tr('"','').downcase
          puts "[.] old #{k}=#{old_mac}"
          old_automac = _name2macpart(old_vm_name)
          if old_automac && old_mac[-old_automac.size..-1] == old_automac
            new_automac = _name2macpart(new_vm_name)
            new_mac = old_mac[0,old_mac.size-new_automac.size] + new_automac
            puts "[.] new #{k}=#{new_mac}"
            modify new_vm_name, k, new_mac, :quiet => true
          end
        end
      end
      new_vm_name
    end

    def modify name, k, v, params = {}
      vboxmanage :modifyvm, name, k => v
      if $?.success? && !params[:quiet]
        h = get_vm_info(k == 'name' ? v : name)
        puts "#{k}=#{h[k]}"
      end
    end

    def delete name
      vboxmanage :unregistervm, name, "--delete"
    end
    alias :destroy :delete
  end
end
