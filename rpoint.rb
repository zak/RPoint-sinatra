require 'rubygems'
require 'sinatra'
require 'models'

helpers do
  include Rack::Utils
  
  alias_method :h, :escape_html
  
  def redirect_to obj
    redirect 
  end
  
end

before do
  @test = request.path_info
end

get '/about' do
  haml :about
end

get '/courses' do
  @courses = Course.all
  haml :'courses/index'
end

get '/course' do
  haml :'courses/add'
end

post '/course' do
  course = Course.new
  course.attributes = params #refactored it
  course.save!
  redirect course.permalink
end

get '/:course' do
  @course = Course.first(:permalink => params[:course])
  haml :'courses/show'
end

get '/:course/del' do
  Course.first(:permalink => params[:course]).destroy
  redirect '/'
end

get '/:course/:lecture' do
  @user = '/:course/:lecture'
  haml :index
end

get '/:course/:lecture/:user' do
  @user = '/:course/:lecture/:user'
  haml :index
end

get '/' do
  @user = User.first.login
  haml :index
end
