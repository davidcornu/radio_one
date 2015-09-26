require 'fileutils'

require_relative '../radio_one'
require_relative "../bulk_downloader"
require_relative "../ffmpeg"

module RadioOne
  class EpisodeDownloader
    def initialize(episode)
      @episode = episode
    end

    def download!
      FileUtils.mkdir_p(target_dir)

      downloads = BulkDownloader.new(
        segments[:urls],
        target_dir,
        headers: {"Cookie" => segments[:auth_cookies].join("; ")}
      ).download!

      FFmpeg.concatenate!(downloads.values, target_file)

      target_file
    end

    def cleanup!
      FileUtils.rm_rf(target_dir)
    end

    private

    def target_dir
      File.join(RadioOne.tmp_dir, @episode.media_pid)
    end

    def output_file
      File.join(target_dir, "#{@episode.media_pid}.aac")
    end

    def base_url
      "http://open.live.bbc.co.uk/mediaselector/5/redir/version/2.0/vpid/#{@episode.media_pid}/mediaset/audio-syndication/proto/http"
    end

    def http
      RadioOne.http
    end

    def stream_info_url
      @stream_info_url ||= fetch_stream_info_url
    end

    def fetch_stream_info_url
      response = http.get(base_url)
      if response.status != 302
        raise Error, "Failed to fetch strema info url for media #{@episode.media_pid}"
      end
      response.headers["Location"]
    end

    class NaiveParamsEncoder
      def self.decode(qs)
        Hash[qs.split("&").map { |q| q.split("=", 2) }]
      end

      def self.encode(params)
        params.map { |*kv| kv.join("=")  }.join("&")
      end
    end

    def segments
      @segments ||= fetch_segments
    end

    def fetch_segments
      response = http.get do |req|
        req.options.params_encoder = NaiveParamsEncoder
        req.url stream_info_url
      end

      unless response.success?
        raise Error, "Failed to fetch stream info for media #{@episode.media_pid}"
      end

      auth_cookies = response.headers["Set-Cookie"]
        .split(/,\s?/)
        .map { |c| c.split(/;\s?/).first }

      playlist_url = response.body.lines.find { |l| l.start_with?("http") }.strip

      playlist_response = http.get do |req|
        req.url playlist_url
        req.headers["Cookie"] = auth_cookies.join("; ")
      end

      unless playlist_response.success?
        raise Error, "Failed to fetch playlist for media #{@episode.media_pid}"
      end

      {
        auth_cookies: auth_cookies,
        urls: playlist_response.body.lines.select { |l| l.start_with?("http") }.map(&:strip)
      }
    end
  end
end
