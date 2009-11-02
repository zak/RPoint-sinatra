require 'rubygems'
require 'sinatra'
require 'models'
require 'usersystem'

use Rack::Static, :urls => ["/css", "/images", "/files"], :root => "public"

helpers do
  include Rack::Utils
  
  alias_method :h, :escape_html
  
  def back
    request.referer
  end
   
  def logged_in?
    !!(@current_user || authenticat_by_cookies)
  end
  
  def authenticat_by_cookies
    session = Session.first(:token => request.cookies["token"]) unless request.cookies["token"].nil? || request.cookies["token"].empty?
    @current_user = session.user unless session.nil?
  end
  
  def authenticat_by_password(user, password)
    return false unless @current_user = User.first(:login => user, :password => UserSystem.encrypt(password))
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
  
  def logout
    @current_user.sessions.destroy if @current_user
    delete_cookie("token")
  end
  
  def authorized?(event = 'logged_in')
    logged_in? && accessed?(event) || access_denied
  end
  
  def access_denied
    redirect '/accessdenied'
  end
  
  def accessed?(event)
    @current_user.accessed?(event)
  end
  
end

before do
  access_page = ['/signup', '/accessdenied', '/about', '/login']
  redirect '/login' unless logged_in? || access_page.include?(request.path)

  @test = request.path_info
  @path = request.path
  @query = request.query_string
  @referer = request.referer 
  @media = request.media_type
end

get '/about' do
  haml :about
end

get '/accessdenied' do
  haml :accessdenied
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
    password = UserSystem.random_string(8)
    user = User.new(:login => params[:login], :email => params[:email], :password => UserSystem.encrypt(password))
    user.save!
    @message = 'Ваш пасс - ' + password + ' И поменять его вы не сможете ))'
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

get '/logout' do
  logout
  redirect '/'
end

#------------
# Права доступа
#------------

get '/permissions' do
  authorized?('permissions_view')
  @permissions = Permission.all
  @users = User.all
  haml :'permissions/index'
end

post '/permissions' do
  authorized?('permissions_add')
  Permission.new(params).save!
  redirect '/permissions'
end

get '/permissions/user/:login' do
  authorized?('permissions_view')
  @user = User.first(:login => params[:login])
  @permissions = Permission.all - @user.permissions
  haml :'permissions/user'
end

get '/permissions/:permission' do
  authorized?('permissions_view')
  @permission = Permission.first(:event => params[:permission])
  @users = User.all - @permission.users
  haml :'permissions/permission'
end

get '/permissions/:permission/del' do
  authorized?('permissions_del')
  Permission.first(:event => params[:permission]).destroy
  redirect '/permissions'
end

get '/permissions/:permission/edit' do
  authorized?('permissions_edit')
  @permission = Permission.first(:event => params[:permission])
  haml :'permissions/edit'
end

post '/permissions/:permission' do
  authorized?('permissions_edit')
  @permission = Permission.first(:event => params[:permission])
  @permission.update_attributes(:event => params[:event], :description => params[:description])
  redirect 'permissions/' + @permission.event
end

post '/permission/add' do
  authorized?('permit')
  Permit.new(params).save!
  redirect request.referer
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
  authorized?('course_add')
  haml :'courses/add'
end

# create course
post '/course' do
  authorized?('course_add')
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
  authorized?('course_edit')
  course = Course.first(:permalink => params[:course])
  course.update_attributes = params.merge(:updated_at => Time.now) #refactored it
  course.save!
  redirect course.permalink
end

# TODO удалять выставляя статус
# delete course
get '/:course/del' do
  authorized?('course_del')
  Course.first(:permalink => params[:course]).destroy
  redirect '/'
end

#------------
# Лекции
#------------

# add form
get '/:course/lecture' do
  authorized?('lecture_add')
  @course = Course.first(:permalink => params[:course])
  haml :'lectures/add'
end

# create lecture
post '/:course/lecture' do
  authorized?('lecture_add')
  @course = Course.first(:permalink => params[:course])
  lecture = Lecture.new(:course => @course, :subject => params[:subject], :number => params[:number], :content => params[:content], :fieldwork => params[:fieldwork], :created_at => Time.now)
  lecture.save!
  redirect '/' + @course.permalink
end

# read lecture
get '/:course/:lecture' do
  @course = Course.first(:permalink => params[:course])
  @lecture = @course.lectures.first(:number => params[:lecture])
  @fieldworks = @lecture.fieldworks(:user => @current_user)
  haml :'lectures/show'
end

# update lecture
post '/:course/:lecture' do
  @course = Course.first(:permalink => params[:course])
  @lecture = @course.lectures.first(:number => params[:lecture])
end

# creat thesis
post '/:course/:lecture/thesis' do
  #authorized?("thesis_for_#{h params[:course]}")
  authorized?("thesis_add")
  @course = Course.first(:permalink => params[:course])
  @lecture = @course.lectures.first(:number => params[:lecture])
  @lecture.theses.new(:content => params[:content], :appraisal => params[:appraisal]).save!
  redirect "/#{params[:course]}/#{params[:lecture]}"
end

# post fieldwork
post '/:course/:lecture/fieldwork' do
  course = Course.first(:permalink => params[:course])
  lecture = course.lectures.first(:number => params[:lecture])
  file_params = params[:attach]
  output_file = "#{course.permalink}-#{@current_user.login}-#{file_params[:filename]}"
  output_file = File.open('./public/files/'+output_file) { "#{course.permalink}-#{@current_user.login}-#{UserSystem.random_string(4)}-#{file_params[:filename]}" } rescue output_file
  FileUtils.mv file_params[:tempfile].path, './public/files/'+output_file
  lecture.fieldworks.new(:description => params[:description], :attach => output_file, :user_id => @current_user.id, :created_at => Time.now).save!
  redirect '/' + params[:course] + '/' + params[:lecture]
end

# appraisal fieldwork
get '/:course/:lecture/:user' do
  authorized?('appraisal')
  @course = Course.first(:permalink => params[:course])
  @lecture = @course.lectures.first(:number => params[:lecture])
  @user = User.first(:login => params[:user])
  @fieldworks = @lecture.fieldworks(:user => @user)
  haml :'lectures/appraisal'
end

# appraisal fieldwork
post '/:course/:lecture/:user' do
  authorized?('appraisal')
  fieldwork = Fieldwork.first(:id => params[:fieldwork_id])
  params[:marks].each do |thesis_id,mark|
    thesis = Thesis.first(:id => thesis_id)
    fieldwork.appraisals.new(:thesis => thesis, :mark => mark).save!
  end
  redirect "/#{params[:course]}/#{params[:lecture]}/#{params[:user]}"
end

get '/' do
  @user = User.first.login
  haml :index
end
