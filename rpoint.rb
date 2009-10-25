require 'rubygems'
require 'sinatra'
require 'models'
require 'usersystem'

helpers do
  include Rack::Utils
  
  alias_method :h, :escape_html
  
  def protected!
    
  end
   
  def authenticat?
    #@current_user = UserSystem::Guest.new if (token = request.cookies["token"]).nil? || (@current_user = Session.first(:token => token).user).nil?
    #@current_user.tokeniz!
    @current_user = Session.first(:token => request.cookies["token"]).user unless request.cookies["token"].nil? || request.cookies["token"].empty?
  end
  
  def authenticat_by_password(user, password)
    return false unless @current_user = User.first(:login => user, :password => password)
    session_start!
    tokeniz!
    true
  end
  
  def session_start!
    Session.new(:token => UserSystem.random_string(14), :expires_at => Time.now + 21600, :ip => request.ip, :referer => request.referer, :user_id => @current_user.id).save!
  end
   
  def tokeniz!
    set_cookie("token", :value => @current_user.sessions.first.token, :expires => Time.now + 21600)
  end
  
end

before do
  authenticat?
  @test = request.path_info
  @path = request.path
  @query = request.query_string
  @referer = request.referer 
  @media = request.media_type
end

get '/about' do
  haml :about
end
#----------------------------
# Регистрация и аутентификация
#----------------------------

get '/signup' do
  haml :signup
end

post '/signup' do
  invite = Invite.first(:token => params[:invite])
  if invite.nil?
    @message = 'Пропуск ваш, не того образца.'
  elsif invite.expires_at.to_time < Time.now
    @message = 'Фу! Да он протух! Видете плесень на уголке!?'
  elsif invite.value < 1
    @message = 'В вашем пропуске дырочка лишняя'
  else
    invite.value -= 1
    invite.save!
    user = User.new(:login => params[:login], :email => params[:email], :password => '123456')
    user.save!
    @message = 'Ваш пасс - ' + user.password + ' И поменять его вы ене сможете ))'
  end
  haml :signuped
end

get '/login' do
  haml :login
end

post '/login' do
  if authenticat_by_password(params[:login], params[:password])
    redirect '/'
  else
    @message = 'Логин/паксс не верен'
    haml :login
  end
end

#-------------------
# Курсы
#-------------------

# TODO перевести на конечные автоматы

get '/courses' do
  @courses = Course.all
  haml :'courses/index'
end

# add form
get '/course' do
  haml :'courses/add'
end

# create course
post '/course' do
  course = Course.new(params.merge(:created_at => Time.now)) #refactored it
  course.save!
  redirect course.permalink
end

# read course
get '/:course' do
  @course = Course.first(:permalink => params[:course])
  haml :'courses/show'
end

# update course
post '/:course' do
  course = Course.first(:permalink => params[:course])
  course.update_attributes = params.merge(:updated_at => Time.now) #refactored it
  course.save!
  redirect course.permalink
end

# TODO удалять выставляя статус
# delete course
get '/:course/del' do
  Course.first(:permalink => params[:course]).destroy
  redirect '/'
end

#------------
# Лекции
#------------

# add form
get '/:course/lecture' do
  @course = Course.first(:permalink => params[:course])
  haml :'lectures/add'
end

# create lecture
post '/:course/lecture' do
  @course = Course.first(:permalink => params[:course])
  lecture = Lecture.new(:course => @course, :subject => params[:subject], :number => params[:number], :content => params[:content], :fieldwork => params[:fieldwork], :created_at => Time.now)
  lecture.save!
  redirect '/' + @course.permalink
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
