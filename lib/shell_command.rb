require 'logger'
require 'open3'

module ShellCommand
  class Error < StandardError; end

  class << self
    attr_writer :logger

    def logger
      @logger ||= Logger.new("/dev/null")
    end

    def run!(*command)
      logger.debug("[ShellCommand] #{command.join(" ")}")

      stdout, stderr, status = Open3.capture3(*command)
      unless status.success?
        error_message = [
          "Something went wrong",
          "Command: #{command.join(' ')}",
          stderr
        ].join("\n")
        raise Error, error_message
      end

      logger.debug(stderr)

      stdout
    end
  end
end
