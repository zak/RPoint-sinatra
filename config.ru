ENV['RACK_ENV'] = "production"

require 'rpoint'
run Sinatra::Application
