require 'logger'
require 'json'
require 'faraday'

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

    def asset_host
      config.fetch(:asset_host, "127.0.0.1")
    end

    def logger
      @logger ||= Logger.new($stdout)
    end

    private

    def load_config
      raw_config = File.read(File.expand_path("../config.json", __dir__))
      JSON.parse(raw_config, symbolize_names: true)
    end
  end
end
