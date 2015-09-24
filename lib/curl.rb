require 'tempfile'
require_relative './shell_command'

class Curl
  def initialize(cookie_file: tmp_cookie_file)
    @cookie_file = cookie_file
  end

  def get!(url)
    ShellCommand.run!(
      "curl", 
      "--cookie-jar", @cookie_file, 
      "--cookie", @cookie_file, 
      "--verbose", 
      url
    )
  end

  def download!(url, target_file)
    ShellCommand.run!(
      "curl", 
      "--cookie-jar", @cookie_file, 
      "--cookie", @cookie_file, 
      "--verbose",
      "--output", target_file,
      url
    )
    true
  end

  private

  def tmp_cookie_file
    @tmp_cookie_file ||= Tempfile.new('curl-cookie').path
  end
end
