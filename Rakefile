require_relative './lib/radio_one/programme'
require_relative './lib/shell_command'

ShellCommand.logger = RadioOne.logger

desc "Build feed for all configured programmes"
task :build do
  RadioOne.config[:programmes].each do |id|
    p = RadioOne::Programme.new(id)
    p.feed_builder.build!
  end
end
