require_relative '../radio_one'
require_relative './episode'
require_relative './feed_builder'

module RadioOne
  class Programme
    attr_reader :pid

    def initialize(pid)
      @pid = pid
    end

    def title
      raw_info["title"]
    end

    def synopsis
      raw_info["medium_synopsis"] || raw_info["short_synopsis"]
    end

    def image_url
      "http://ichef.bbci.co.uk/images/ic/480x270/#{raw_info["image"]["pid"]}.jpg"
    end

    def episodes
      @episodes ||= raw_episodes.map { |e| Episode.new(e["pid"], self) }
    end

    def link
      "http://www.bbc.co.uk/programmes/#{@pid}"
    end

    def feed_builder
      @feed_builder ||= FeedBuilder.new(self)
    end

    private

    def http
      RadioOne.http
    end

    def info_url
      "http://www.bbc.co.uk/programmes/#{@pid}.json"
    end

    def episodes_url
      "http://www.bbc.co.uk/programmes/#{@pid}/episodes/player.json"
    end

    def raw_info
      @raw_info ||= fetch_raw_info
    end

    def fetch_raw_info
      response = http.get(info_url)
      unless response.success?
        raise Error, "Failed to fetch info for programme #{@pid}"
      end
      JSON.parse(response.body)["programme"]
    end

    def raw_episodes
      @raw_episodes ||= fetch_raw_episodes
    end

    def fetch_raw_episodes
      all = []
      page = 1
      loop do
        response = http.get(episodes_url, page: page)

        break if response.status == 404 && page > 1

        unless response.success?
          raise Error, "Failed to fetch episodes for programme #{@pid}"
        end

        json_body = JSON.parse(response.body)
        break if json_body["page"] != page
        all += json_body["episodes"].map { |e| e["programme"] }
        page += 1
      end
      all
    end
  end
end
