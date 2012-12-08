require 'vbox/cmdlineapi'
require 'digest/md5'
require 'yaml'

class VBoxManageSimulator

  @@log       = Hash.new{ |k,v| k[v] = [] }
  @@responses = {}
  @@replaypos = Hash.new(0)
  @@mode      = nil

  DATAFILE    = __FILE__.sub(/\.rb$/,'') + ".yml"

  class << self

    def mode
      @@mode
    end

    def mode= mode
      @@mode = mode
    end

    def record q, r
      md5 = Digest::MD5.hexdigest(r)

      # make MD5 hashes readable by saving them in default encoding instead of binary
      if md5.to_yaml['binary']
        md5.encode!(Encoding.default_external)
        raise "cannot properly encode #{md5} to ASCII yaml" if md5.to_yaml['binary']
      end

      @@responses[md5] = r
      @@log[$current_test_description] << md5
      r
    end

    def replay q
      pos = @@replaypos[$current_test_description]
      md5 = @@log[$current_test_description][pos]
      @@replaypos[$current_test_description] += 1
      @@responses[md5]
    end

    def process_cmd q, &block
      case @@mode
      when :record
        record q, yield
      when :replay
        replay q
      else
        # do nothing
        yield
      end
    end

    def save fname = DATAFILE
      puts "[*] VBoxManageEmulator: saving #{fname} .."
      if @@log.empty? || @@responses.empty?
        raise "refusing to save empty log"
      end
      File.open(fname,"w") do |f|
        f << { 'log' => @@log, 'responses' => @@responses }.to_yaml
      end
    end

    def load fname = DATAFILE
      data = YAML::load_file(fname)
      @@log, @@responses = data['log'], data['responses']
      @@mode = :replay
    end
  end
end

module VBOX
  class CmdLineAPI

    alias :orig_vboxmanage :vboxmanage
    def vboxmanage *args
      VBoxManageSimulator.process_cmd(args) do
        orig_vboxmanage *args
      end
    end

  end
end

#at_exit do
#  VBoxManageSimulator.save if VBoxManageSimulator.mode == :record
#end
