require 'faraday'
require 'oga'
require_relative './episode'

class Programme
  BASE_URL = "http://www.bbc.co.uk/programmes/%{programme_id}/episodes/player"

  def initialize(programme_id)
    @programme_id = programme_id
  end

  def episodes
    @episodes ||= fetch_episodes
  end

  private

  def http
    @http ||= Faraday.new do |faraday|
      faraday.adapter Faraday.default_adapter
    end
  end

  def base_url
    BASE_URL % {programme_id: @programme_id}
  end

  def each_page
    page = 1
    loop do
      response = http.get(base_url, page: page)
      break unless response.success?
      yield response.body
      page += 1
    end
  end

  def extract_episodes_from_page(page)
    doc = Oga.parse_html(page)
    doc.css("div.programme--episode").map do |el|
      url = el.attr("resource").value
      Episode.new({
        id: url.split("/").last,
        title: el.css(".programme__titles span[property='name']").text.strip,
        description: el.css(".programme__synopsis span[property='description']").text.strip,
        image: el.css(".programme__img meta[property='image']").attr("content").first.value,
        url: url
      })
    end
  end

  def fetch_episodes
    episodes = []
    each_page do |page|
      episodes += extract_episodes_from_page(page)    
    end
    episodes
  end
end
