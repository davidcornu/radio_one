# RadioOne

A giant pile of hacks to convert BBC Radio One shows into podcasts so I don't have to deal with their terrible web player.

## Dependencies

Requires `curl` and `ffmpeg`. All other dependencies are managed by Bundler.

Steps to perform on a Ubuntu 15.04 x64 image on DigitalOcean.

- `sudo apt-add-repository ppa:brightbox/ruby-ng`
- `sudo apt-get update`
- `sudo apt-get install curl ffmpeg git ruby2.2 nginx vim`
- `sudo gem install bundler`
- `sudo ufw allow 22`
- `sudo ufw allow 80`
- `sudo ufw enable`
- `git clone git@github.com:davidcornu/radio_one.git`
- `cd radio_one`
- `bundle install --path vendor/bundle --without test development`
