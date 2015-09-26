require 'thread'
require 'thwait'
require 'uri'

require_relative './shell_command'

class BulkDownloader
  DEFAULT_CONCURRENCY = 10

  def initialize(urls, target_dir, concurrency: DEFAULT_CONCURRENCY, headers: {})
    @target_dir = target_dir
    @urls = urls
    @concurrency = concurrency
    @headers = headers
    @targets = urls.each_with_object({}) do |url, h|
      filename = URI.parse(url).path.split("/").last
      h[url] = File.join(target_dir, filename) 
    end
  end

  def download!
    queue = build_queue
    workers = @concurrency.times.map { spawn_worker(queue) }
    ThreadsWait.all_waits(*workers)
    @targets
  end

  private

  def build_queue
    @urls.each_with_object(Queue.new) { |url, q| q << url }
  end

  def spawn_worker(queue)
    worker = Thread.new do
      begin
        while url = queue.pop(true)
          # ShellCommand.run!(*curl_command_for_url(url))
          puts curl_command_for_url(url).inspect
        end
      rescue ThreadError => e
        raise e unless e.message == "queue empty"
      end
    end
    worker.abort_on_exception = true
    worker
  end

  def curl_command_for_url(url)
    path = @targets[url]
    header_opts = @headers.flat_map { |k,v| ["--header", "#{k}: #{v}"] }
    [
      "curl",
      "--verbose",
      *header_opts,
      "--output", path,
      url
    ]
  end
end
