require 'faraday'
require 'json'

module RadioOne
  class Error < StandardError; end
  
  class << self
    def http
      @http ||= Faraday.new do |faraday|
        faraday.adapter Faraday.default_adapter
        faraday.response :logger
      end
    end

    def public_dir
      File.expand_path("../public", __dir__)
    end

    def tmp_dir
      File.expand_path("../tmp", __dir__)
    end

    def config
      @config ||= load_config
    end

    private

    def load_config
      raw_config = File.read(File.expand_path("../config.json", __dir__))
      JSON.parse(raw_config, symbolize_names: true)
    end
  end
end
