require 'open3'

module ShellCommand
  class Error < StandardError; end

  extend self

  def run!(*command)
    stdout, stderr, status = Open3.capture3(*command)
    unless status.success?
      error_message = [
        "Something went wrong",
        "Command: #{command.join(' ')}",
        stderr
      ].join("\n")
      raise Error, error_message
    end
    stdout
  end
end
