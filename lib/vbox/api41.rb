#module VBOX
#  class API41
#    def initialize
#      require 'virtualbox'
#    end
#
#    def list_vms
#      vms = VirtualBox::VM.all.sort_by(&:name)
#
#      longest = vms.map(&:name).map(&:size).max
#
#      puts "%-*s %5s %6s".gray % [longest, *%w'NAME MEM DIRSZ']
#      vms.each do |vm|
#        s = `du -s -BM "#{File.dirname(vm.settings_file_path)}"`
#        size = s.split("\t").first.tr("M","")
#
#        s = sprintf "%-*s %5d %6s", longest, vm.name, vm.memory_size, size
#        s = "#{s}  RUNNING".green if vm.state == :running
#        puts s
#      end
#    end
#
#    def show_vm_info name
#      vm = VirtualBox::VM.find name
#      unless vm
#        STDERR.puts "[!] cannot find vm #{name.inspect}".red
#        exit 1
#      end
#
#      h = {}
#      vm.methods.each do |m|
#        next if m.size < 4 || m !~ /=$/ || !vm.respond_to?(m1=m[0..-2])
#        r = nil
#        begin
#          r = vm.send(m1)
#        rescue VirtualBox::Exceptions::UnsupportedVersionException
#        end
#        h[m1] = r unless r.nil? || r == ""
#      end
#
#      @longest = h.map{ |k,v| v == false ? 0 : k.size }.max + 1
#      h.each do |k,v|
#        next if v == false
#        printf "%*s: ", @longest, k
#        case v
#        when String, Numeric, TrueClass, FalseClass, Symbol
#          puts v
#        when VirtualBox::AbstractModel
#          p _attrs(v)
#        else
#          _print_value k,v
#        end
#      end
#    end
#
#    def _print_value k,v
#      newline = "\n  "+" "*@longest
#      case k.to_sym
#      when :boot_order, :extra_data
#        p v
#      when :shared_folders
#        puts v.map{ |f| _attrs(f).inspect }.join(newline)
#      when :network_adapters
#        puts v.find_all{ |x| x.enabled }.map{ |x| _attrs(x).inspect }.join(newline)
#      when :medium_attachments
#        v.each_with_index do |ma, idx|
#          print newline if idx > 0
#          print _attrs(ma)
#          if ma.medium
#            print newline + "  "
#            p _attrs(ma.medium)
#          end
#        end
#      when :storage_controllers
#        puts v.map{ |f| _attrs(f).inspect }.join(newline)
#      else
#        puts v.class.to_s.red
#      end
#    end
#
#    def _attrs x
#      return nil unless x.respond_to?(:attributes)
#      x.attributes.reject{ |k,v|
#        [:parent, :interface].include?(k) || v == "" || v.to_s['VirtualBox::']
#      }
#    end
#  end
#end
