require 'faraday'
require 'oga'
require 'json'
require 'thread'
require 'thwait'

BASE_URL = "http://www.bbc.co.uk/programmes/b006wkh9/episodes/player"
WORKER_COUNT = 10

conn = Faraday.new do |faraday|
  faraday.adapter Faraday.default_adapter
end

pages = []

$stderr.puts "Fetching episode listings"

(1..Float::INFINITY).each do |i|
  response = conn.get(BASE_URL, page: i)
  break unless response.success?
  pages << response.body
end

results = pages.flat_map do |page|
  doc = Oga.parse_html(page)
  doc.css("div.programme--episode").map do |el|
    url = el.attr("resource").value
    {
      id: url.split("/").last,
      title: el.css(".programme__titles span[property='name']").text.strip,
      description: el.css(".programme__synopsis span[property='description']").text.strip,
      image: el.css(".programme__img meta[property='image']").attr("content").first.value,
      url: url
    }
  end
end

$stderr.puts "Found #{results.length} episodes"

workers = []
track_listings = Queue.new
work_queue = Queue.new
results.each { |r| work_queue << r }

$stderr.puts "Spawning #{WORKER_COUNT} workers to fetch track listings"

WORKER_COUNT.times do
  worker = Thread.new do
    until work_queue.empty?
      result = work_queue.pop
      $stderr.puts result[:url]
      segments_url = begin
        response = conn.get(result[:url] + '/segments')
        raise "Failed to find segments url for #{result[:id]}" unless response.status == 302
        path = response.headers[:location]
        URI.parse(result[:url]).tap { |u| u.path = path }.to_s
      end
      response = conn.get(segments_url)
      raise "Could not load segments page for #{result[:id]}" unless response.success?
      doc = Oga.parse_html(response.body)
      listing = {id: result[:id]}
      listing[:tracks] = doc.css("div.segment--music").map do |el|
        {
          artist: el.css("[property='byArtist'] [property='name']").text.strip,
          title: el.css(".segment__track > p").text.strip
        }
      end
      track_listings << listing
    end
  end
  worker.abort_on_exception = true
  workers << worker
end

ThreadsWait.all_waits(*workers)

until track_listings.empty?
  listing = track_listings.pop
  result = results.find { |r| r[:id] == listing[:id] }
  result[:tracks] = listing[:tracks]
end

puts results
