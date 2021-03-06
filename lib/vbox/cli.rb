#!/usr/bin/env ruby
require 'awesome_print'
require 'optparse'

module VBOX

  ALIASES  = {'clonevm'=>'clone', 'destroy'=>'delete', 'rm'=>'delete'}

  class CLI
    def initialize argv = ARGV
      @argv = argv
    end

    private
    def _join_by_width words, params = {}
      params[:max_length] ||= 30
      params[:separator]  ||= ", "
      params[:newline]    ||= "\n"
      lines = []
      line = []
      words.each do |word|
        if (line+[word]).join(params[:separator]).size > params[:max_length]
          lines << line.join(params[:separator])
          line = []
        end
        line << word
      end
      lines << line.join(params[:separator]) unless line.empty?
      lines.join params[:newline]
    end

    public
    def banner
      bname = File.basename($0)
      r = []
      r << "USAGE:"
      r << "\t#{bname} [options]                           - list VMs"
      r << "\t#{bname} [options] <vm_name>                 - show VM params"
      r << "\t#{bname} [options] <vm_name> <param>=<value> - change VM params (name, cpus, usb, etc)"
      r << "\t#{bname} [options] <vm_name> <command>       - make some action (start, reset, etc) on VM"

      r << ""
      r << "COMMANDS:"
#      (COMMANDS+['snapshots']).sort.each do |c|
#        r << "\t#{c}"
#      end
      r << "\t" + _join_by_width(COMMANDS+['snapshots'], :newline => ",\n\t", :max_length => 64 )
      r << ""
      r << "OPTIONS:"
      r.join("\n")
    end

    def examples
      bname = File.basename($0)
      space = " "*bname.size
      r = []
      r << "EXAMPLES:"
      r << %Q{\t#{bname} -v                        - list VMs with memory and dir sizes}
      r << %Q{\t#{bname} "d{1-10}" list            - list only VMs named 'd1','d2','d3',...,'d10'}
      r << %Q{\t#{bname} "test*" start             - start VMs which name starts with 'test'}
      r << %Q{\t#{bname} "v[ace]" cpus=2 acpi=on   - set number of cpus & ACPI on VMs named 'va','vc','ve'}
      r << %Q{\t#{bname} d0                        - list all parameters of VM named 'd0'}
      r << %Q{\t#{bname} d0 clone -c 10 -S last    - make 10 new linked clones of vm 'd0' using the}
      r << %Q{\t#{space}                             latest hdd snapshot, if any}
      r << %Q{\t#{bname} d0 clone -c 10 -S new     - make ONE new shapshot of VM 'd0' and then make}
      r << %Q{\t#{space}                             10 new clones linked to this snapshot}
      r << %Q{\t#{bname} "tmp?" delete             - try to destroy all VMs which name is 4 letters long}
      r << %Q{\t#{space}                             and starts with 'tmp'}
      r << %Q{\t#{bname} ae340207-f472-4d63-80e7-855fca6808cb}
      r << %Q{\t#{space}                           - list all parameters of VM with this GUID}
      r << %Q{\t#{bname} --no-glob "*wtf?!*" rm    - destroy VM which name is '*wtf?!*'}
      r.join("\n")
    end

    def parse_argv
      @options = { :verbose => 0 }
      optparser = OptionParser.new do |opts|
        opts.banner = banner
        opts.summary_indent = "\t"

        opts.on "-g", "--[no-]glob",
        "assume <vm_name> is a wildcard & run on multiple VMs.",
        "All glob(7) patterns are supported plus additional",
        "pattern \"{1-20}\" - expands to a sequence: 1,2,3,...,19,20" do |x|
          @options[:multiple] = x
        end
        opts.on "-n", "--dry-run", "do not change anything, just print commands to be invoked" do
          @options[:dry_run] = true
        end
        opts.on "-v", "--verbose", "increase verbosity" do
          @options[:verbose] ||= 0
          @options[:verbose] += 1
        end
        opts.on "-N", "--clones N", Integer, "clone: make N clones" do |x|
          @options[:clones] = x
        end
        a = 'new last take make'.split.map{ |x| [x, x.upcase] }.flatten
        opts.on "-S", "--snapshot MODE", a, "clone: use LAST shapshot or make NEW" do |x|
          @options[:snapshot] = x.downcase
        end
        opts.on "--name NAME", "clone: name for the clone VM" do |x|
          @options[:name] = x
        end
        opts.on "-H", "--headless", "start: start VM in headless mode" do
          @options[:headless] = true
        end
        opts.on "-h", "--help", "show this message" do
          puts @help
          exit
        end
      end
      @help = optparser.help + "\n" + examples
      @argv = optparser.parse(@argv)

      # disable glob matching if first arg is a UUID
      unless @options.key?(:multiple)
        @options[:multiple] = "{#{@argv.first}}" !~ UUID_RE
      end

      VBOX.verbosity = @options[:verbose]
    end

    def list_vms name_or_glob
      vms = _find_vms name_or_glob

      longest = (vms.map(&:name).map(&:size)+[4]).max

      puts "%-*s %5s %6s  %-12s %s".gray % [longest, *%w'NAME MEM DIRSZ STATE UUID']
      vms.each do |vm|
        if @options[:verbose] > 0
          vm.fetch_metadata
          state = (vm.state == :poweroff) ? '' : vm.state.to_s.upcase
          s = sprintf "%-*s %5d %6s  %-12s %s", longest, vm.name, vm.memory_size, vm.dir_size,
            state, vm.uuid
        else
          state = (vm.state == :poweroff) ? '' : vm.state.to_s.upcase
          s = sprintf "%-*s %5s %6s  %-12s %s", longest, vm.name, '', '',
            state, vm.uuid
        end
        s = s.green if vm.state == :running
        puts s
      end
    end

    def vm_cmd name_or_glob, cmd='show', *args
      vms = _find_vms(name_or_glob)
      if vms.empty?
        if cmd == 'create'
          return vm_cmd_create(name_or_glob)
        else
          STDERR.puts "[?] no VMs matching #{name_or_glob.inspect}".red
          exit 1
        end
      end

      method =
        if cmd['=']
          # set some VM variables:
          # vbox vm_name foo=bar bar=baz xxx=yyy
          args.unshift(cmd)
          "vm_cmd_set"
        else
          "vm_cmd_#{cmd}"
        end

      unless self.respond_to?(method)
        STDERR.puts "[?] unknown command #{cmd.inspect}".red
        exit 1
      end
      vms.each do |vm|
        send method, vm, *args
      end
    end

    SHOW_CATEGORIES = {
      'GENERAL'          => %w'name cpus memory vram cpuexecutioncap UUID VMState',
      'VIRTUALIZATION OPTIONS' =>
        [
          /^(groups|ostype|hwvirt|nestedpag|largepag|vtxvpid|ioapic|pagefusion|hpet|synthcpu|pae)/,
          /accelerate/, /balloon/i
        ],
      'NET'              => [ /^(nic|nat|mac|bridge|cable|hostonly)/, /^sock/, /^tcp/ ],
      'STORAGE'          => [ /storage/, /SATA/, /IDE/ ],
      'SNAPSHOTS'        => [ /snapshot/i ],
      'VIRTUAL HARDWARE' => [ /^(lpt|uart|audio|ehci|usb|hardware|chipset|monitor|hid|acpi|firmware|USB)/ ],
      'TELEPORTING'      => [ /teleport/i, /cpuid/i ],
      'SHARED FOLDERS'   => [ /SharedFolder/ ]
    }

    public
    def vm_cmd_show vm
      vars = vm.metadata.dup
      unless @options[:verbose] > 0
        vars.delete_if{ |k,v| ["none","off","disabled","emptydrive","",0,"0",nil].include?(v) }
      end
      maxlen = vars.keys.map(&:size).max

      SHOW_CATEGORIES.each do |name, filters|
        keys = []; title = nil
        filters.each do |filter|
          keys += filter.is_a?(Regexp) ? vars.keys.find_all{ |key| key =~ filter } : [filter]
        end
        keys.each do |k|
          if v = vars.delete(k)
            puts (title = "--- #{name} ".ljust(80,'-')) unless title
            printf("  %-*s: %s\n", maxlen, k, v)
          end
        end
      end
      puts "--- MISC ".ljust(80,'-')
      vars.each do |k,v|
        printf("  %-*s: %s\n", maxlen, k, v)
      end
    end

    # create VM
    def vm_cmd_create name
      VM.new(:name => name).create!
    end

    # destroy VM
    def vm_cmd_destroy vm
      vm.destroy!
    end
    alias :vm_cmd_rm     :vm_cmd_destroy
    alias :vm_cmd_delete :vm_cmd_destroy

    # set VM variables
    def vm_cmd_set vm, *args
      raise "all arguments must contain '='" unless args.all?{ |arg| arg['='] }
      args.each do |arg|
        k,v = arg.split("=",2)
        vm.set_var k, v
      end
      vm.save
    end

    # start VM
    def vm_cmd_start vm
      vm.start! :headless => @options[:headless]
    end

    # pause VM
    def vm_cmd_pause vm
      vm.pause!
    end

    # resume VM
    def vm_cmd_resume vm
      vm.resume!
    end
    alias :vm_cmd_unpause :vm_cmd_resume

    # reset VM
    def vm_cmd_reset vm
      vm.reset!
    end

    # save VM state
    def vm_cmd_savestate vm
      vm.savestate!
    end
    alias :vm_cmd_save_state :vm_cmd_savestate

    # stop VM
    def vm_cmd_poweroff vm
      vm.poweroff!
    end
    alias :vm_cmd_stop :vm_cmd_poweroff

    # ACPI 'Power' Button
    def vm_cmd_acpipowerbutton vm
      vm.acpipowerbutton!
    end

    # ACPI 'Sleep' Button
    def vm_cmd_acpisleepbutton vm
      vm.acpisleepbutton!
    end

    # clone VM
    def vm_cmd_clone vm
      # TODO: page fusion
      unless @options[:snapshot]
        puts "[!] please gimme --snapshot=LAST OR --snapshot=NEW option".red
        exit 1
      end
      vm.clone! @options
    end

    # manage VM snapshots
    def vm_cmd_snapshots vm, *args
      vm.snapshots.each do |s|
        printf "%s  %s\n", s.uuid, s.name
      end
    end
    alias :vm_cmd_snapshot :vm_cmd_snapshots

    def run
      parse_argv
      # now @argv contains only VM name and commands, if any

      if @argv.empty? || (@argv.size <= 2 && @argv.include?('list'))
        # vbox
        # vbox list
        # vbox list "a*"
        # vbox "a*" list
        @argv.delete_at(@argv.index('list') || 999) # delete only 1st 'list' entry
        list_vms @argv.first
      elsif @argv.empty? || (@argv.size <= 2 && @argv.include?('ls'))
        # vbox
        # vbox ls
        # vbox ls "a*"
        # vbox "a*" ls
        @argv.delete_at(@argv.index('ls') || 999) # delete only 1st 'ls' entry
        list_vms @argv.first
      else
        # vbox VM
        # vbox VM show
        # vbox VM ...
        #  - where 'VM' can be vm name or glob or UUID
        vm_cmd *@argv
      end
    end

    private

    def _find_vms name_or_glob
      if name_or_glob
        if @options[:multiple]
          # glob
          VM.find_all(name_or_glob)
        else
          # exact name
          [ VM.find(name_or_glob) ]
        end
      else
        # all VMs
        VM.all
      end
    end
  end

end


if $0 == __FILE__
  VBOX::CLI.new.run
end
