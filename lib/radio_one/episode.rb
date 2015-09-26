require_relative '../radio_one'
require_relative './episode_downloader'

module RadioOne
  class Episode
    def initialize(pid)
      @pid = pid
    end

    def title
      raw_info["title"]
    end

    def synopsis
      raw_info["medium_synopsis"] || info["short_synopsis"]
    end

    def image_url
      "http://ichef.bbci.co.uk/images/ic/480x270/#{raw_info["image"]["pid"]}.jpg"
    end

    def media_pid
      raw_info["versions"].find { |v| v["canonical"] == 1 }["pid"]
    end

    def tracks
      raw_segments.map do |s|
        title = s["title"]
        artists_by_role = s["contributions"].each_with_object({}) do |c, h|
          (h[c["role"]] ||= []) << c["name"]
        end
        
        if featured_artists = artists_by_role["Featured Artist"]
          title += " - feat. #{featured_artists.join(", ")}"
        end

        {
          title: title,
          artist: artists_by_role["Performer"].join(", "),
          label: s["record_label"]
        }
      end
    end

    def download!
      download.download!
    end

    private

    def downloader
      @downloader ||= EpisodeDownloader.new(self)
    end

    def http
      RadioOne.http
    end

    def info_url
      "http://www.bbc.co.uk/programmes/#{@pid}.json"
    end

    def segments_url
      "http://open.live.bbc.co.uk/aps/programmes/#{media_pid}/segments.json"
    end

    def raw_info
      @raw_info ||= fetch_raw_info
    end

    def fetch_raw_info
      response = http.get(info_url)
      unless response.success?
        raise Error, "Failed to fetch info for episode #{@pid}"
      end
      JSON.parse(response.body)["programme"]
    end

    def raw_segments
      @raw_segments ||= fetch_raw_segments
    end

    def fetch_raw_segments
      response = http.get(segments_url)
      unless response.success?
        raise Error, "Failed to fetch segments for episode #{@pid}"
      end
      JSON.parse(response.body)["segment_events"].map { |e| e["segment"] }
    end
  end
end
