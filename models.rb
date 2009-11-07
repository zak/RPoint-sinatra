require 'rubygems' 
require 'dm-core'
require 'usersystem'
require 'md5'

class DateTime
  def rfc822
    self.strftime "%a, %d %b %Y %H:%M:%S %z"
  end
  
  def to_post
    self.strftime "%d %b %Y %H:%M"
  end
end

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3:///#{Dir.pwd}/../rpoint.db")
#DataMapper::Logger.new('dm.log', :debug, "\n", true)
DataMapper::Logger.new(STDOUT, 0)
DataObjects::Sqlite3.logger = DataObjects::Logger.new(STDOUT, 0)

class User < UserSystem::BasisUser
  include DataMapper::Resource

  
  property :id, Serial
  property :login, String, :length => 0..255, :unique => true, :key => true
  property :email, String, :nullable => false, :unique => true, :format => :email_address, :key => true
  property :password, String, :length => 0..255
  property :state, String, :length => 0..255
  property :token, String, :length => 0..255
  property :token_expires_at, DateTime
  property :created_at, DateTime
  property :updated_at, DateTime
  
  has n, :owncourses, :model => 'Course'
  has n, :fieldworks
  has n, :invites
  has n, :sessions
  has n, :comments
  
  has n, :permits
  has n, :permissions, :through => :permits
  
  has n, :subcourses
  has n, :courses, :through => :subcourses
  
  has n, :sublectures
  has n, :lectures, :through => :sublectures
  
  belongs_to :invite
  
  def avatar
    "http://www.gravatar.com/avatar/#{MD5::md5(email.downcase)}?s=30"
  end
end

class Permit
  include DataMapper::Resource
  
  property :id, Serial
  
  belongs_to :user
  belongs_to :permission
end

class Permission
  include DataMapper::Resource
  
  property :id, Serial
  property :event, String, :length => 0..255
  property :description, Text
  
  has n, :permits
  has n, :users, :through => :permits  
end

class Session
  include DataMapper::Resource
  
  property :id, Serial
  property :token, String, :length => 0..15
  property :expires_at, DateTime
  property :ip, String, :length => 0..18
  property :referer, String, :length => 0..255
  
  belongs_to :user
  
  has n, :notifications
end

class Notification
  include DataMapper::Resource
  
  property :id, Serial
  property :message, String, :length => 0..255
  property :read, Boolean, :default => false
  property :created_at, DateTime
  
  belongs_to :session
end

class Invite
  include DataMapper::Resource
  
  property :id, Serial
  property :token, String, :length => 0..255
  property :value, Integer, :default  => 1
  property :expired_at, DateTime
  property :created_at, DateTime
  
  belongs_to :user
  has n, :users
end

class Course
  include DataMapper::Resource
  
  property :id, Serial
  property :title, String, :length => 0..255
  property :permalink, String, :length => 0..225
  property :state, String, :length => 0..255
  property :teaser, Text
  property :description, Text
  property :created_at, DateTime
  property :updated_at, DateTime
  
  belongs_to :user
  
  has n, :lectures
  
  has n, :subcourses
  has n, :users, :through => :subcourses
end

class Subcourse
  include DataMapper::Resource
  
  property :id, Serial
  
  belongs_to :course
  belongs_to :user
end

class Lecture
  include DataMapper::Resource
  
  property :id, Serial
  property :number, Integer 
  property :subject, String, :length => 0..255
  property :state, String, :length => 0..255
  property :content, Text
  property :fieldwork, Text
  property :created_at, DateTime
  property :updated_at, DateTime
  
  belongs_to :course
  
  has n, :theses
  has n, :fieldworks
  
  has n, :sublectures
  has n, :users, :through => :sublectures
  
  def next
    Lecture.first(:course_id => self.course_id, :number.gt => self.number, :order => [:number.asc])
  end
end

class Sublecture
  include DataMapper::Resource
  
  property :id, Serial
  
  belongs_to :lecture
  belongs_to :user
end

class Thesis
  include DataMapper::Resource
  
  property :id, Serial
  property :content, Text
  property :appraisal, String, :length => 0..255
  
  belongs_to :lecture
  
  has n, :appraisals
end

class Fieldwork
  include DataMapper::Resource
  
  property :id, Serial
  property :description, Text
  property :attach, String, :length => 0..255
  property :created_at, DateTime
  
  belongs_to :lecture
  belongs_to :user
  
  has n, :appraisals
end

class Appraisal
  include DataMapper::Resource
  
  property :id, Serial
  property :mark, String, :length => 0..255
  
  belongs_to :thesis
  belongs_to :fieldwork
end

class Comment
  include DataMapper::Resource
  
  property :id, Serial
  property :page, String, :length => 0..255
  property :comment, Text
  property :created_at, DateTime

  belongs_to :user
end

def install
  DataMapper.auto_migrate!
  
  User.new(:login => 'admin', :password => '7c4a8d09ca3762af61e59520943dc26494f8941b', :email => 'admin@rpoint.ru', :invite_id => 1, :created_at => Time.now).save!
  user = User.new(:login => 'zak', :password => '0f0109c6a2ee3e044aa6be74f92995daa86949bf', :email => 'zak@rpoint.ru', :invite_id => 1, :created_at => Time.now)
  user.save!
  { :course_add => 'Добавить новый курс', :course_del => 'Удалить курс', :course_edit => 'Редактировать курс',
    :lecture_add => 'Добавить лекцию',  :lecture_edit => 'Редактировать лекцию', :lecture_del => 'Удалить лекцию',
    :thesis_add => 'Добавить тезис', :thesis_del => 'Удалить тезис', :thesis_edit => 'Редактировать тезис',
    :appraisal => 'Поставить оценку',
    :permit => 'Раздача привелегий',
    :permissions_view => 'Просмотр привелегий', :permissions_add => 'Добавление привелегий', :permissions_del => 'Удаление привелегий', :permissions_edit => 'Редактирование привелегий',
    :invite_add => 'Создать инвайт'}.find_all do |event, description|
    p = Permission.new(:event => event, :description => description)
    p.save!
    user.permissions << p
    user.save!
  end
  
 # user.owncourses.new(:title => 'Тестовый', :permalink => 'test', :description => 'Не очень длинный текст, а хотелось больше!', :state => 'public', :created_at => Time.now).save!
  user.invites.new(:token => '123456789', :created_at => Time.now, :value => 0, :expired_at => (Time.now + 3600)).save!
 # user.invites.new(:token => '123', :value => 0, :created_at => (Time.now - 3600), :expired_at => (Time.now)).save!
 # Lecture.new(:number => 1, :subject => 'Первая лекция', :content => 'Сама теория припрвленная <b>кодом</b>', :fieldwork => 'Практическое задание', :state => 'public', :course_id => 1, :created_at => Time.now).save!
 # Lecture.new(:number => 2, :subject => 'Вторая лекция', :content => 'Сама теория припрвленная <b>кодом</b>', :fieldwork => 'Практическое задание', :state => 'public', :course_id => 1, :created_at => Time.now + 3600).save!
 # Lecture.new(:number => 3, :subject => 'Третья лекция', :content => 'Сама теория припрвленная <b>кодом</b>', :fieldwork => 'Практическое задание', :state => 'public', :course_id => 1, :created_at => Time.now + 7200).save!
 # Thesis.new(:content => 'Форматирование кода', :appraisal => "1|2|3|4|5", :lecture_id => 1).save!
 # Thesis.new(:content => 'Семантика', :appraisal => "1|2|3|4|5", :lecture_id => 1).save!
 # Thesis.new(:content => 'Реализация таблицы', :appraisal => "1|2|3|4|5", :lecture_id => 2).save!
 # Thesis.new(:content => 'Оценка', :appraisal => "1|2|3|4|5", :lecture_id => 2).save!
end
