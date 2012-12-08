require 'vbox/cmdlineapi'
require 'digest/md5'
require 'yaml'

class VBoxManageSimulator

  # a weird way of defining class variables
  @log       = Hash.new{ |k,v| k[v] = [] }
  @responses = {}
  @replaypos = Hash.new(0)
  @debug     = false

  DATAFILE    = __FILE__.sub(/\.rb$/,'') + ".yml"

  class << self
    attr_accessor :mode

    def before_all
      puts "#{self}: BEFORE ALL".yellow if @debug
      @current_test_description = nil
    end

    def after_all
      puts "#{self}: AFTER ALL".yellow if @debug
      @current_test_description = nil
    end

    def before_each example
      puts "#{self}: BEFORE EACH".yellow if @debug
      @current_test_description = example.full_description
      return if @mode != :replay

      Open3.should_not_receive(:popen3)
      Kernel.should_not_receive(:system)
      Kernel.should_not_receive(:`)

      Array(@log[@current_test_description]).each do |args,md5|
        puts "[d] WANT: #{args.inspect}" if @debug
        response = @responses[md5]
        VBOX.api.should_receive(:vboxmanage).with(*args).and_return(response)
      end
    end

    def after_each example
      puts "#{self}: AFTER EACH".yellow if @debug
      @current_test_description = nil
    end

    def record args, r
      md5 = Digest::MD5.hexdigest(r)

      # make MD5 hashes readable by saving them in default encoding instead of binary
      if md5.to_yaml['binary']
        md5.encode!(Encoding.default_external)
        raise "cannot properly encode #{md5} to ASCII yaml" if md5.to_yaml['binary']
      end

      @responses[md5] = r
      @log[@current_test_description] << [args, md5]
      r
    end

    def replay args
      pos = @replaypos[@current_test_description]
      args, md5 = @log[@current_test_description][pos]
      @replaypos[@current_test_description] += 1
      @responses[md5]
    end

    def process_cmd args, &block
      puts "[d]  GOT: #{args.inspect} in #{@current_test_description.inspect}" if @debug
      case @mode
      when :record
        record args, yield
      when :replay
        @current_test_description ? yield : replay(args)
      else
        # do nothing
        yield
      end
    end

    def save fname = DATAFILE
      data = { 'log' => @log, 'responses' => @responses }.to_yaml
      puts
      puts "[*] VBoxManageEmulator: #{@log.size} actions, #{@responses.size} unique responses, #{data.size} bytes"
      puts "[*] VBoxManageEmulator: saving #{fname} .. "
      if @log.empty? || @responses.empty?
        raise "refusing to save empty log"
      end
      File.open(fname,"w") do |f|
        f << data
      end
    end

    def load fname = DATAFILE
      data = YAML::load_file(fname)
      @log, @responses = data['log'], data['responses']
      @mode = :replay
    end
  end
end

module VBOX
  class CmdLineAPI

    alias :orig_vboxmanage :vboxmanage
    def vboxmanage *args
      VBoxManageSimulator.process_cmd(args) do
        puts "[d] calling original".red if @debug
        orig_vboxmanage *args
      end
    end

    alias :orig_success? :success?
    def success?
      if VBoxManageSimulator.mode == :replay
        true
      else
        orig_success?
      end
    end

  end
end

#at_exit do
#  VBoxManageSimulator.save if VBoxManageSimulator.mode == :record
#end
