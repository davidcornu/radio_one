set :output, File.expand_path("../tmp/cron.log", __dir__)
env :PATH, ENV['PATH']

every 1.hour do
  rake "build"
end
