set :output, File.expand_path("../tmp/cron.log", __dir__)

every 2.hours do
  rake "build"
end
