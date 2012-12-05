#!/usr/bin/env ruby
require 'awesome_print'
require 'optparse'

# for natural sort order
# http://stackoverflow.com/questions/4078906/is-there-a-natural-sort-by-method-for-ruby
class String
  def naturalized
    scan(/[^\d]+|\d+/).collect { |f| f.match(/\d+/) ? f.to_i : f }
  end
end

module VBOX

  COMMANDS = %w'start pause resume reset poweroff savestate acpipowerbutton acpisleepbutton clone delete show'
  ALIASES  = {'clonevm'=>'clone', 'destroy'=>'delete', 'rm'=>'delete'}

  UUID_RE  = /\{\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\}/

  class CLI
    def initialize argv = ARGV
      @argv = argv
    end

    def banner
      bname = File.basename(__FILE__)
      r = []
      r <<  "USAGE:"
      r <<  "\t#{bname} [options]                           - list VMs"
      r <<  "\t#{bname} [options] <vm_name>                 - show VM params"
      r <<  "\t#{bname} [options] <vm_name> <param>=<value> - change VM params (name, cpus, usb, etc)"
      r <<  "\t#{bname} [options] <vm_name> <command>       - make some action (start, reset, etc) on VM"

      r <<  ""
      r <<  "COMMANDS:"
      (COMMANDS+['snapshots']).sort.each do |c|
        r <<  "\t#{c}"
      end
      r <<  ""
      r <<  "OPTIONS:"
      r.join("\n")
    end

    def run
      @options = { :verbose => 0 }
      optparser = OptionParser.new do |opts|
        opts.banner = banner

        opts.on "-m", "--[no-]multiple",
        "(default: auto) assume <vm_name> is a wildcard,",
        "and run on multiple VMs.",
        "All glob(7) patterns like *,?,[a-z] are supported",
        "plus additional pattern {1-20} which matches","a sequence of numbers: 1,2,3,...,19,20" do |x|
          @options[:multiple] = x
        end
        opts.on "-n", "--dry-run", "do not change anything, just print commands to be invoked" do
          @options[:dry_run] = true
        end
        opts.on "-v", "--verbose", "increase verbosity" do
          @options[:verbose] ||= 0
          @options[:verbose] += 1
        end
        opts.on "-c", "--clones N", Integer, "clone: make N clones" do |x|
          @options[:clones] = x
        end
        a = 'new last take make'.split.map{ |x| [x, x.upcase] }.flatten
        opts.on "-snapshot", "--snapshot MODE", a, "clone: use LAST shapshot or make NEW" do |x|
          @options[:snapshot] = x.downcase
        end
        opts.on "-H", "--headless", "start: start VM in headless mode" do
          @options[:headless] = true
        end
        opts.on "-h", "--help", "show this message" do
          puts @help
          exit
        end
      end
      @help = optparser.help
      @argv = optparser.parse(@argv)

      # disable glob matching if first arg is a UUID
      unless @options.key?(:multiple)
        @options[:multiple] = "{#{@argv.first}}" !~ UUID_RE
      end

      @vbox = VBOX::CmdLineAPI.new(@options)

      if @argv.size == 0 || @argv.last == 'list'
        vms = @vbox.list_vms
        @vbox.list_vms(:running => true).each do |vm|
          vms.find{ |vm1| vm1.uuid == vm.uuid }.state = :running
        end

        if @argv.size == 2 && @argv.last == 'list'
          if @options[:multiple]
            @globs = _expand_glob(@argv.first).flatten
            vms = vms.keep_if{ |vm| _fnmatch(vm.name) }
          else
            vms = vms.keep_if{ |vm| vm.name == @argv.first }
          end
        end

        longest = (vms.map(&:name).map(&:size)+[4]).max

        puts "%-*s %5s %6s  %-12s %s".gray % [longest, *%w'NAME MEM DIRSZ STATE UUID']
        vms.each do |vm|
          if @options[:verbose] > 0
            @vbox.get_vm_details vm
            state = (vm.state == :poweroff) ? '' : vm.state.to_s.upcase
            s = sprintf "%-*s %5d %6s  %-12s %s", longest, vm.name, vm.memory_size||0, vm.dir_size||0,
              state, vm.uuid
          else
            state = (vm.state == :poweroff) ? '' : vm.state.to_s.upcase
            s = sprintf "%-*s %5s %6s  %-12s %s", longest, vm.name, '', '',
              state, vm.uuid
          end
          s = s.green if vm.state == :running
          puts s
        end
      else
        name = @argv.shift
        cmd  = @argv.shift || 'show' # default command is 'show'

        cmd = ALIASES[cmd] if ALIASES[cmd]
        if @options[:multiple]
          _run_multiple_cmd cmd, name
        else
          _run_cmd cmd, name
        end
      end
    end

    # expand globs like "d{1-30}" to d1,d2,d3,d4,...,d29,d30
    def _expand_glob glob
      if glob[/\{(\d+)-(\d+)\}/]
        r = []
        $1.to_i.upto($2.to_i) do |i|
          r << _expand_glob(glob.sub($&,i.to_s))
        end
        r
      else
        [glob]
      end
    end

    def _fnmatch fname
      @globs.each do |glob|
        return true if File.fnmatch(glob, fname)
      end
      false
    end

    def _run_multiple_cmd cmd, name
      vms = @vbox.list_vms
      @globs = _expand_glob(name).flatten
      vms.each do |vm|
        if _fnmatch(vm.name)
          _run_cmd cmd, vm.name
        end
      end
    end

    def _run_cmd cmd, name
      if COMMANDS.include?(cmd)
        @vbox.send cmd, name
      elsif cmd['=']
        # set some variable, f.ex. "macaddress1=BADC0FFEE000"
        @vbox.modify name, *cmd.split('=',2)
      elsif cmd == 'snapshots'
        @vbox.get_snapshots(name).each do |x|
          printf "%s  %s\n", x.uuid, x.name
        end
      else
        STDERR.puts "[!] unknown command #{cmd.inspect}".red
        puts @help
        exit 1
      end
    end
  end

  VMInfo = Struct.new :name, :uuid, :memory_size, :dir_size, :state
  Snapshot = Struct.new :name, :uuid

  class CmdLineAPI
    def initialize options={}
      @options = options
      @options[:verbose] ||= 2 if @options[:dry_run]
      @options[:verbose] ||= 0
    end

    # run as in backtick operator, and return result
    def ` cmd
      puts "[.] #{cmd}".gray if @options[:verbose] >= 2
      exit if @options[:dry_run]
      r = super
      #exit 1 unless $?.success?
      r
    end

    # run as in system() call
    def system *args
      puts "[.] #{args.inspect}".gray if @options[:verbose] >= 2
      exit if @options[:dry_run]
      r = super
      exit 1 unless $?.success?
      r
    end

    def get_vm_details vm
      data = `VBoxManage showvminfo #{vm.uuid} --machinereadable`
      data.each_line do |line|
        a = line.strip.split('=',2)
        next unless a.size == 2
        k,v = a
        case k
        when 'memory'
          vm.memory_size = v.to_i
        when 'VMState'
          vm.state = v.tr('"','').to_sym
        when 'CfgFile'
          dir = File.dirname(v.tr('"',''))
          s = `du -s -BM "#{dir}"`
          vm.dir_size = s.split("\t").first.tr("M","")
        end
      end
      vm
    end

    def list_vms params = {}
      if params[:running]
        data = `VBoxManage list runningvms`
      else
        data = `VBoxManage list vms`
      end
      r = []
      data.strip.each_line do |line|
        if line[UUID_RE]
          vm = VMInfo.new
          vm.uuid = $&
          vm.name = line.gsub($&, '').strip.sub(/^"/,'').sub(/"$/,'')
          r << vm
        end
      end
      r.sort_by{ |vm| vm.name.naturalized }
    end

    def get_vm_info name
      data = `VBoxManage showvminfo "#{name}" --machinereadable`
      h = {}
      data.each_line do |line|
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
      class_eval <<-EOF unless instance_methods.include?(cmd.to_sym)
        def #{cmd} name
          system "VBoxManage", "controlvm", name, "#{cmd}"
        end
      EOF
    end

    def start name
      if ENV['DISPLAY'] && !@options[:headless]
        system "VBoxManage", "startvm", name
      else
        puts "[.] $DISPLAY is not set, assuming --headless".gray unless @options[:headless]
        @options[:headless] = true
        system "VBoxManage", "startvm", name, "--type", "headless"
      end
    end


    def get_snapshots _name
      r = []
      name = uuid = nil
      `VBoxManage snapshot "#{_name}" list --machinereadable`.strip.each_line do |line|
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
      system "VBoxManage", "snapshot", vm_name, "take", params[:name] || "noname"
      exit 1 unless $?.success?
      get_snapshots(vm_name).last
    end

    def _name2macpart name
      r = name.scan(/\d+/).map{ |x| "%02x" % x }.join
      r == '' ? nil : r
    end

    def clone old_vm_name
      @clone_use_snapshot = nil
      (@options[:clones] || 1).times{ _clone(old_vm_name) }
    end

    def _clone old_vm_name
      args = []
      if new_vm_name = @options['name'] || _gen_vm_name(old_vm_name)
        args += ["--name", new_vm_name]
      end

      snapshot = @clone_use_snapshot ||= case @options[:snapshot]
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

      args += ["--options","link"]
      args += ["--register"]
      args += ["--snapshot", snapshot.uuid]

      system "VBoxManage", "clonevm", old_vm_name, *args

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
    end

    def modify name, k, v, params = {}
      system "VBoxManage", "modifyvm", name, "--#{k}", v
      if $?.success? && !params[:quiet]
        h = get_vm_info(k == 'name' ? v : name)
        puts "#{k}=#{h[k]}"
      end
    end

    def delete name
      system "VBoxManage", "unregistervm", name, "--delete"
    end
  end
end


if $0 == __FILE__
  VBOX::CLI.new.run
end
