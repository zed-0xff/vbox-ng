require 'vbox/vm'
require 'vbox/cmdlineapi'

module VBOX
  # UUID_RE  = /\{\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\}/ # only in ruby 1.9 :(
  UUID_RE  = /\{[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\}/i

  @@verbosity = ENV['VBOX_DEBUG'].to_i

  class << self
    def api
      @@api ||= CmdLineAPI.new
    end

    def verbosity
      @@verbosity
    end

    def verbosity= v
      @@verbosity = v
    end
  end
end
