require 'vbox/vm'
require 'vbox/cmdlineapi'

module VBOX
  # UUID_RE  = /\{\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\}/ # only in ruby 1.9 :(
  UUID_RE  = /\{[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\}/i

  def self.api
    @@api ||= CmdLineAPI.new
  end
end
