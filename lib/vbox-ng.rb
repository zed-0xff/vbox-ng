require 'vbox/vm'
require 'vbox/cmdlineapi'

module VBOX
  UUID_RE  = /\{\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\}/

  def self.api
    @@api ||= CmdLineAPI.new
  end
end
