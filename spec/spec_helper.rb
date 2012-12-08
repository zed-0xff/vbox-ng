require 'simplecov'
SimpleCov.start

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'vbox-ng'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

# Cross-platform way of finding an executable in the $PATH.
#   which('ruby') #=> /usr/bin/ruby
#
# http://stackoverflow.com/questions/2108727/which-in-ruby-checking-if-program-exists-in-path-from-ruby
def which(cmd)
  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    exts.each { |ext|
      exe = "#{path}/#{cmd}#{ext}"
      return exe if File.executable? exe
    }
  end
  return nil
end

RSpec.configure do |config|
  config.before :suite do
    if ENV['SIMULATE_VBOXMANAGE'] || !which('VBoxManage')
      puts "[*] VBoxManage executable not found in $PATH, using simulation..."
      VBoxManageSimulator.load
    elsif ENV['RECORD_VBOXMANAGE']
      VBoxManageSimulator.mode = :record
    end
  end

  config.before :all do
    VBoxManageSimulator.before_all
  end

  config.before :each do
    VBoxManageSimulator.before_each example
  end

  config.after :each do
    VBoxManageSimulator.after_each example
  end

  config.after :all do
    VBoxManageSimulator.after_all
  end

  config.after :suite do
    VBoxManageSimulator.save if ENV['RECORD_VBOXMANAGE']
  end
end
