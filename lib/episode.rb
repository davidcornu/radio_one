require 'faraday'
require 'oga'
require 'virtus'
require_relative './episode_downloader'

class Episode
  include Virtus.model

  attribute :id, String
  attribute :title, String
  attribute :description, String
  attribute :image, String
  attribute :url, String

  def tracks
    @tracks ||= fetch_tracks
  end

  def download!
    downloader.download!
  end

  private

  def http
    @http ||= Faraday.new do |faraday|
      faraday.adapter Faraday.default_adapter
    end
  end

  def downloader
    @downloader ||= EpisodeDownloader.new(self)
  end

  def segments_url
    @segments_url ||= fetch_segments_url
  end

  def fetch_segments_url
    response = http.get(url + '/segments')
    raise "Failed to find segments url for #{id}" unless response.status == 302
    path = response.headers[:location]
    URI.parse(url).tap { |u| u.path = path }.to_s
  end

  def fetch_tracks
    response = http.get(segments_url)
    raise "Could not load segments page for #{id}" unless response.success?
    doc = Oga.parse_html(response.body)
    doc.css("div.segment--music").map do |el|
      {
        artist: el.css("[property='byArtist'] [property='name']").text.strip,
        title: el.css(".segment__track > p").text.strip
      }
    end
  end
end
