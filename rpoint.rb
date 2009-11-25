require 'rubygems'
require 'sinatra'
require 'haml'
require 'models'
require 'usersystem'

use Rack::Static, :urls => ["/css", "/images", "/files"], :root => "public"

class UserNotFound < NameError
  def code 
    404
  end
end

#set :show_exceptions, false

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
    @session = Session.first(:token => request.cookies["token"]) unless request.cookies["token"].nil? || request.cookies["token"].empty?
    @current_user = @session.user unless @session.nil?
  end
  
  def authenticat_by_password(user, password)
    return false unless @current_user = User.first(:login => user, :password => UserSystem.encrypt(password))
    session_start!
    tokeniz!
    true
  end
  
  def session_start!
    @session = @current_user.sessions.new(:token => UserSystem.random_string(14), :expires_at => Time.now + 21600, :ip => request.ip, :referer => request.referer, :user_id => @current_user.id)
    @session.save!
  end
   
  def tokeniz!
    set_cookie("token", :value => @session.token, :expires => Time.now + 21600)
  end
  
  def logout
    @session.destroy if @current_user
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
  
  def comments
    haml :comments, :layout => false
  end
  
  def escape_javascript(javascript)
    if javascript
      javascript.gsub(/(on.*=["'].*["']|<script>.*<\/script>)/) { '' }
    else
      ''
    end
  end
  
  def notification(message)
    @session.notifications.new(:message => message, :created_at => Time.now, :read => false).save!
  end
  
  def notifications
    return [] if @session.nil?
    @notifications ||= @session.notifications.all(:read => false).each {|n| n.read = true; n.save!}
  end
  
  def notifications_all
    @session.notifications.all(:order => [:created_at.desc], :limit => 10)
  end
  
  def access_course?(course)
    @current_user.courses.include?(course) || course.user == @current_user || (!(p = Permission.first(:event => "course_edit_#{course.id}")).nil? && p.users.include?(@current_user))
  end
  
  def access_lecture?(lecture)
    @current_user.lectures.include?(lecture) || accessed?("lecture_edit")
  end
  
end

before do
  access_page = ['/signup', '/accessdenied', '/about', '/login', '/404']
  redirect '/login' unless logged_in? || access_page.include?(request.path)
  @body_class = ''
end

get '/about' do
  haml :about
end

get '/accessdenied' do
  haml :accessdenied
end

get '/accessdeniedcourse' do
  haml :accessdeniedcourse
end

get '/accessdeniedlecture' do
  haml :accessdeniedlecture
end

get '/404' do
  status 404
  haml :'404'
end

get '/index' do
  @comments = Comment.all(:page => request.path)
  haml :index
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
  elsif invite.expired_at.to_time < Time.now
    @message = 'Фу! Да он протух! Видете плесень на уголке!?'
  elsif invite.value < 1
    @message = 'В вашем пропуске дырочка лишняя'
  else
    invite.value -= 1
    invite.save!
    password = UserSystem.random_string(8)
    user = invite.users.new(:login => params[:login], :email => params[:email], :password => UserSystem.encrypt(password), :created_at => Time.now)
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
    notification 'Вход успешно осуществлен'
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
  Permission.new(:event => params[:event], :description => params[:description]).save! ? notification("Привелегия #{params[:event]} добавленна") : notification('Произошла какаето херня и привелегия не добавленна')
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
  raise "Привелегия #{params[:permission]} не найдена." if @permission.nil?
  @users = User.all - @permission.users
  haml :'permissions/permission'
  
end

get '/permissions/:permission/del' do
  authorized?('permissions_del')
  Permission.first(:event => params[:permission]).destroy ? notification("Привелегия #{params[:permission]} удалина") : notification("Не удалось удалить #{params[:permission]}")
  redirect '/permissions'
end

get '/permissions/:permission/edit' do
  authorized?('permissions_edit')
  @permission = Permission.first(:event => params[:permission])
  haml :'permissions/edit'
end

# update permission
post '/permissions/:permission' do
  authorized?('permissions_edit')
  @permission = Permission.first(:event => params[:permission])
  @permission.update_attributes(:event => params[:event], :description => params[:description]) ? notification("Привелегия #{params[:permission]} изменина") : notification("Не удалось изменить привелегию #{params[:permission]}")
  redirect 'permissions/' + @permission.event
end

post '/permission/add' do
  authorized?('permit')
  Permit.new(params).save!
  redirect request.referer
end

#-------------------
# Пользователи
#-------------------

get '/users' do
  @users = User.all
  haml :'users/list'
end

get '/user/:login' do
  @user = User.first(:login => params[:login])
  raise UserNotFound, "Пользователь #{h params[:login]} не найден." if @user.nil?
  haml :'users/show'
end

get '/dashbord' do
  haml :'users/dashbord'
end

post '/dashbord/pass' do
  @current_user.password = UserSystem.encrypt(params[:password]) if params[:password] == params[:confirm] && @current_user.password == UserSystem.encrypt(params[:old_pass])
  @current_user.save! ? notification("Пароль изменен") : notification("Старый пароль еще в силе!")
  redirect '/dashbord'
end

# create invites
post '/dashbord/invite' do
  authorized?('invite_add')
  @current_user.invites.new(:value => params[:value], :expired_at => Time.now + params[:expired].to_f * 3600 * 24, :created_at => Time.now, :token => UserSystem.random_string(12)).save! ? notification("Пирожки готовы"): notification("Херь какаето, попробуй еще")
  redirect '/dashbord'
end

error UserNotFound do
  haml :not_found
end

#-------------------
# Комментарии
#-------------------

post '*/comment' do
  Comment.new(:page => params["splat"], :comment => escape_javascript(params[:comment]), :user => @current_user, :created_at => Time.now).save! ? notification("Ты испачкал страницу #{params["splat"]}") : notification("Господь не дал опорочить твоими речами эту страницу!")
  redirect params["splat"]
end

#-------------------
# Курсы
#-------------------

# TODO перевести на конечные автоматы

get '/courses' do
  @courses = Course.all
  @body_class = 'courses'
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
  course = @current_user.owncourses.new(:permalink => params[:permalink], :description => params[:description], :title => params[:title], :created_at => Time.now) 
  course.save! ? notification('Курс добавлен') : notification('Мы не справились с этим запросом')
  redirect params[:permalink]
end

# read course
get '/:course' do
  @course = Course.first(:permalink => params[:course])
  redirect '/accessdeniedcourse' unless access_course?(@course)
  @comments = Comment.all(:page => request.path)
  haml :'courses/show'
end

get '/:course/buy' do
  course = Course.first(:permalink => params[:course])
  @current_user.courses << course
  @current_user.lectures << course.lectures.first(:order => [:number.asc])
  @current_user.save! ? notification("Вы подписались на курс #{course.title}") : notification('Хм, вам не удалось подписаться на курс')
  redirect '/'+params[:course]
end

get '/:course/edit' do
  authorized?('course_edit')
  @course = Course.first(:permalink => params[:course])
  haml :'courses/edit'
end

# update course
post '/:course' do
  authorized?('course_edit')
  course = Course.first(:permalink => params[:course])
  course.update_attributes(:permalink => params[:permalink], :description => params[:description], :title => params[:title], :updated_at => Time.now) ? notification("Изменения '#{params[:title]}' прошли успешно") : notification('Курс не поддался')
  redirect course.permalink
end

# TODO удалять выставляя статус
# delete course
get '/:course/del' do
  authorized?('course_del')
  Course.first(:permalink => params[:course]).destroy ? notification("Ты только что пришиб #{params[:course]}") : notification("Он сопративляется!")
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
  lecture.save! ? notification("Отличная лекция #{params[:subject]}") : notification('Что то пошло не так и мы потеряли сей труд')
  redirect '/' + @course.permalink
end

# read lecture
get '/:course/:lecture' do
  @course = Course.first(:permalink => params[:course])
  @lecture = @course.lectures.first(:number => params[:lecture])
  redirect '/accessdeniedlecture' unless access_lecture?(@lecture)
  @fieldworks = @lecture.fieldworks(:user => @current_user)
  @comments = Comment.all(:page => request.path)
  haml :'lectures/show'
end

get '/:course/:lecture/del' do
  authorized?('lecture_del')
  course = Course.first(:permalink => params[:course])
  lecture = course.lectures.first(:number => params[:lecture])
  lecture.destroy ? notification('Все ее больше нет ((') : notification('Is a live!!!')
  redirect "/#{params[:course]}"
end

get '/:course/:lecture/edit' do
  authorized?('lecture_edit')
  @course = Course.first(:permalink => params[:course])
  @lecture = @course.lectures.first(:number => params[:lecture])
  haml :'lectures/edit'
end

# update lecture
post '/:course/:lecture' do
  authorized?('lecture_edit')
  course = Course.first(:permalink => params[:course])
  lecture = course.lectures.first(:number => params[:lecture])
  lecture.update_attributes(:number => params[:number], :subject => params[:subject], :content => params[:content], :fieldwork => params[:fieldwork], :updated_at => Time.now) ? notification("В #{params[:subject]} что то поменялось") : notification('Изменения не внесены')
  redirect "/#{params[:course]}/#{lecture.number}"
end

# creat thesis
post '/:course/:lecture/thesis' do
  #authorized?("thesis_for_#{h params[:course]}")
  authorized?("thesis_add")
  @course = Course.first(:permalink => params[:course])
  @lecture = @course.lectures.first(:number => params[:lecture])
  @lecture.theses.new(:content => params[:content], :appraisal => params[:appraisal]).save! ? notification('Тэзис добавлен') : notification('Он не лезет!')
  redirect "/#{params[:course]}/#{params[:lecture]}"
end

# post fieldwork
post '/:course/:lecture/fieldwork' do
  course = Course.first(:permalink => params[:course])
  lecture = course.lectures.first(:number => params[:lecture])
  unless params[:attach].nil?
    file_params = params[:attach]
    output_file = "#{course.permalink}-#{@current_user.login}-#{file_params[:filename]}"
    output_file = File.open('./public/files/'+output_file) { "#{course.permalink}-#{@current_user.login}-#{UserSystem.random_string(4)}-#{file_params[:filename]}" } rescue output_file
    FileUtils.mv file_params[:tempfile].path, './public/files/'+output_file
  else
    output_file = false
  end
  lecture.fieldworks.new(:description => params[:description], :attach => output_file, :user => @current_user, :created_at => Time.now).save! ? notification('Уверен, что это стоит показывать?') : notification('Придется поработать еще')
  redirect '/' + params[:course] + '/' + params[:lecture]
end

# appraisal fieldwork
get '/:course/:lecture/:user' do
  authorized?('appraisal') if @current_user.login != params[:user]
  @course = Course.first(:permalink => params[:course])
  @lecture = @course.lectures.first(:number => params[:lecture])
  @user = User.first(:login => params[:user])
  @fieldworks = @lecture.fieldworks(:user => @user)
  @comments = Comment.all(:page => request.path)
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
  notification('Этим двоечникам явно не повезло')
  redirect "/#{params[:course]}/#{params[:lecture]}/#{params[:user]}"
end

get '/:course/:lecture/:user/next' do
  authorized?('appraisal')
  @course = Course.first(:permalink => params[:course])
  @lecture = @course.lectures.first(:number => params[:lecture])
  @user = User.first(:login => params[:user])
  @user.lectures << @lecture.next unless @lecture.next.nil?
  @user.save
  redirect "/#{params[:course]}/#{params[:lecture]}"
end

get '/' do
  redirect '/index'
end

error NoMethodError do
  haml :not_found
end

error do
  haml :'404'
end

not_found do
  haml :'404'
end
