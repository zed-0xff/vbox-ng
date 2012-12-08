# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "vbox-ng"
  gem.homepage = "http://github.com/zed-0xff/vbox-ng"
  gem.license = "MIT"
  gem.summary = %Q{A comfortable way of doing common VirtualBox tasks.}
  gem.description = %Q{Create/start/stop/reboot/modify dozens of VirtualBox VMS with one short command.}
  gem.email = "zed.0xff@gmail.com"
  gem.authors = ["Andrey \"Zed\" Zaikin"]
  # dependencies defined in Gemfile

  gem.executables = %w'vbox'
  gem.files.include "lib/**/*.rb"
  gem.files.exclude "samples/*", "README.md.tpl"
  gem.extra_rdoc_files.exclude "README.md.tpl"
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

task :default => :spec

#require 'rdoc/task'
#Rake::RDocTask.new do |rdoc|
#  version = File.exist?('VERSION') ? File.read('VERSION') : ""
#
#  rdoc.rdoc_dir = 'rdoc'
#  rdoc.title = "vbox-ng #{version}"
#  rdoc.rdoc_files.include('README*')
#  rdoc.rdoc_files.include('lib/**/*.rb')
#end

desc "build readme"
task :readme do
  require 'erb'
  tpl = File.read('README.md.tpl').gsub(/^%\s+(.+)/) do |x|
    x.sub! /^%/,''
    "<%= run(\"#{x}\") %>"
  end
  def run cmd
    cmd.strip!
    puts "[.] #{cmd} ..."
    r = "    # #{cmd}\n\n"
    cmd.sub! /^vbox/,"./bin/vbox"
    lines = `#{cmd}`.sub(/\A\n+/m,'').sub(/\s+\Z/,'').split("\n")
    lines = lines[0,25] + ['...'] if lines.size > 50
    r << lines.map{|x| "    #{x}"}.join("\n")
    r << "\n"
  end
  result = ERB.new(tpl,nil,'%>').result
  File.open('README.md','w'){ |f| f << result }
end
