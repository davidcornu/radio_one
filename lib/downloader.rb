PROGRAM_ID = "b067w3np"
TARGET_URL = "http://open.live.bbc.co.uk/mediaselector/5/redir/version/2.0/vpid/#{PROGRAM_ID}/mediaset/audio-syndication/proto/http"
WORKER_COUNT = 10
SEGMENTS_DIR = File.join(__dir__, PROGRAM_ID)
COOKIE_FILE = File.join(SEGMENTS_DIR, "cookies.txt")

require 'open3'
require 'oga'
require 'thread'
require 'thwait'
require 'fileutils'
require 'uri'

# Clean up
$stderr.puts "Preparing target directory"
FileUtils.rm_rf(SEGMENTS_DIR)
FileUtils.mkdir_p(SEGMENTS_DIR)

class ShellError < StandardError; end

def run_shell_command!(*command)
  stdout, stderr, status = Open3.capture3(*command)
  unless status.success?
    error_message = [
      "Something went wrong",
      "Command: #{command.join(' ')}",
      stderr
    ].join("\n")
    raise ShellError, error_message
  end
  stdout
end

module Curl
  extend self

  def get!(url)
    run_shell_command!(
      "curl", 
      "--cookie-jar", COOKIE_FILE, 
      "--cookie", COOKIE_FILE, 
      "--verbose", 
      url
    )
  end

  def download!(url, target_file)
    run_shell_command!(
      "curl", 
      "--cookie-jar", COOKIE_FILE, 
      "--cookie", COOKIE_FILE, 
      "--verbose",
      "--output", target_file,
      url
    )
    true
  end
end

# Fetch body from 302 response and get manifest url
$stderr.puts "Fetching manifest url"
doc = Oga.parse_html(Curl.get!(TARGET_URL))
unless manifest_href = doc.css('a').attribute('href').first
  raise "Program \"#{PROGRAM_ID}\" does not exist"
end
manifest_url = manifest_href.value

# Fetch manifest and get playlist url
$stderr.puts "Fetching playlist url"
m3u = Curl.get!(manifest_url)
playlist_url = m3u.lines.find { |l| l.start_with?('http') }

# Fetch playlist and extract segment urls
$stderr.puts "Fetching playlist"
playlist = Curl.get!(playlist_url.strip)
segment_urls = playlist.lines.select { |l| l.start_with?("http") }.map(&:strip)

segment_files = segment_urls.each_with_object({}) do |url, hash|
  hash[url] = File.join(SEGMENTS_DIR, URI.parse(url).path.split("/").last)
end

$stderr.puts "Found #{segment_files.length} segments"

# Download segments in parallel
work_queue = Queue.new
workers = []
segment_files.each { |url, file| work_queue << [url, file] }

$stderr.puts "Spawning #{WORKER_COUNT} download workers"

WORKER_COUNT.times do
  worker = Thread.new do
    until work_queue.empty?
      url, file = work_queue.pop
      $stderr.puts "Downloading #{url}"
      Curl.download!(url, file)
    end
  end
  worker.abort_on_exception = true
  workers << worker
end

ThreadsWait.all_waits(*workers)

$stderr.puts "Successfully downloaded #{segment_files.length} segments"

# Build ffmpeg input file
ffmpeg_manifest = File.join(SEGMENTS_DIR, "ffmpeg_manifest.txt")
File.write(
  ffmpeg_manifest, 
  segment_files.values.map { |file| "file '#{file}'" }.join("\n") + "\n"
)

$stderr.puts "Concatenating segments with ffmpeg"

# Concatenate segments with ffmpeg
output_file = File.join(__dir__, "#{PROGRAM_ID}.aac")
FileUtils.rm_rf(output_file)
run_shell_command!(
  "ffmpeg",
  "-f", "concat",
  "-i", ffmpeg_manifest,
  "-vn",
  "-acodec", "copy",
  output_file
)

puts output_file
