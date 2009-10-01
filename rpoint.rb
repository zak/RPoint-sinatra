require 'rubygems'
require 'sinatra'
require 'models'

helpers do

  include Rack::Utils
  
  alias_method :h, :escape_html
  
end

get '/' do
  @user = Users.first
  haml :index
end
