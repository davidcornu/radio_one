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
      return output_file if File.exist?(output_file)

      FileUtils.mkdir_p(download_dir)

      downloads = BulkDownloader.new(
        segments[:urls],
        download_dir,
        headers: {"Cookie" => segments[:auth_cookies].join("; ")}
      ).download!

      FileUtils.mkdir_p(output_dir)
      FFmpeg.concatenate!(downloads.values, output_file)

      output_file
    ensure
      FileUtils.rm_rf(download_dir)
    end

    private

    def download_dir
      File.join(RadioOne.tmp_dir, @episode.media_pid)
    end

    def output_dir
      File.join(RadioOne.public_dir, @episode.programme.pid)
    end

    def output_file
      File.join(output_dir, "#{@episode.media_pid}.aac")
    end

    def base_url
      "http://open.live.bbc.co.uk/mediaselector/5/select/version/2.0/vpid/#{@episode.media_pid}/format/json/mediaset/apple-iphone4-hls/"
    end

    def http
      RadioOne.http
    end

    def stream_info_url
      @stream_info_url ||= fetch_stream_info_url
    end

    def fetch_stream_info_url
      response = http.get(base_url)
      unless response.success?
        raise Error, "Failed to fetch stream info url for media #{@episode.media_pid}"
      end

      connection = JSON.parse(response.body)
        .fetch("media", [{}])
        .first.fetch("connection", [])
        .find { |c| c["protocol"] == "http" }

      return connection["href"] if connection
      raise Error, "Could not find http stream for media #{@episode.media_pid}"
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

      auth_cookies = response.headers.fetch("Set-Cookie", "")
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
