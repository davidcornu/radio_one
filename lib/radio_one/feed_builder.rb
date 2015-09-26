require 'fileutils'
require 'erb'
require 'time'

require_relative "../radio_one"

module RadioOne
  class FeedBuilder
    include ERB::Util

    def self.template
      @template ||= begin
        template_path = File.expand_path("./rss_feed.erb", __dir__)
        template = ERB.new(File.read(template_path))
        template.filename = template_path
        template
      end
    end

    def initialize(programme)
      @programme = programme
    end

    def build!
      File.write(
        File.join(target_dir, "feed.xml"),
        render_rss_feed
      )
    end

    private

    def render_rss_feed
      self.class.template.result(binding)
    end

    def target_dir
      File.join(RadioOne.public_dir, @programme.pid)
    end

    def public_url(path)
      return unless path.start_with?(RadioOne.public_dir)
      path.sub(RadioOne.public_dir, "http://#{RadioOne.asset_host}")
    end
  end
end
