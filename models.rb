require 'rubygems' 
require 'dm-core'
require 'usersystem'

class DateTime
  def rfc822
    self.strftime "%a, %d %b %Y %H:%M:%S %z"
  end
end

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3:///#{Dir.pwd}/../rpoint.db")

class User < UserSystem::BasisUser
  include DataMapper::Resource

  
  property :id, Serial
  property :login, String, :length => 0..255
  property :email, String, :length => 0..255
  property :password, String, :length => 0..255
  property :state, String, :length => 0..255
  property :token, String, :length => 0..255
  property :token_expires_at, DateTime
  property :created_at, DateTime
  property :updated_at, DateTime
  
  has n, :courses
  has n, :fieldworks
  has n, :invites
  has n, :sessions
  
  has n, :permits
  has n, :permissions, :through => :permits
  
  #before :save do 
  #  self.password = UserSystem.encrypt(self.password) if self.id.nil?
  #end
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
end

class Invite
  include DataMapper::Resource
  
  property :id, Serial
  property :token, String, :length => 0..255
  property :value, Integer, :default  => 1
  property :expires_at, DateTime
  property :created_at, DateTime
  
  belongs_to :user
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
end

class Lecture
  include DataMapper::Resource
  
  property :id, Serial
  property :number, Integer 
  property :subject, String, :length => 0..255
  property :content, Text
  property :fieldwork, Text
  property :created_at, DateTime
  property :updated_at, DateTime
  
  belongs_to :course
  
  has n, :theses
  has n, :fieldworks
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

def install
  DataMapper.auto_migrate!
  
  User.new(:login => 'admin', :password => '7c4a8d09ca3762af61e59520943dc26494f8941b').save!
  user = User.new(:login => 'zak', :password => '0f0109c6a2ee3e044aa6be74f92995daa86949bf')
  user.save!
  { :course_add => 'Добавить новый курс', :course_del => 'Удалить курс', :course_edit => 'Редактировать курс',
    :lecture_add => 'Добавить лекцию',  :lecture_edit => 'Редактировать лекцию', :lecture_del => 'Удалить лекцию',
    :thesis_add => 'Добавить тезис', :thesis_del => 'Удалить тезис', :thesis_edit => 'Редактировать тезис',
    :appraisal => 'Поставить оценку',
    :permit => 'Раздача привелегий',
    :permissions_view => 'Просмотр привелегий', :permissions_add => 'Добавление привелегий', :permissions_del => 'Удаление привелегий',
    :permissions_edit => 'Редактирование привелегий'}.find_all do |event, description|
    p = Permission.new(:event => event, :description => description)
    p.save!
    user.permissions += [p]
    user.save!
  end
  
  Course.new(:title => 'Тестовый', :permalink => 'test', :description => 'Не очень длинный текст, а хотелось больше!', :user_id => 1).save!
  Invite.new(:token => '123456789', :created_at => Time.now, :expires_at => (Time.now + 3600), :user_id => 1).save!
  Invite.new(:token => '123', :created_at => (Time.now - 3600), :expires_at => (Time.now), :user_id => 1).save!
  Lecture.new(:number => 1, :subject => 'Первая лекция', :content => 'Сама теория припрвленная <b>кодом</b>', :fieldwork => 'Практическое задание', :course_id => 1).save!
  Lecture.new(:number => 2, :subject => 'Вторая лекция', :content => 'Сама теория припрвленная <b>кодом</b>', :fieldwork => 'Практическое задание', :course_id => 1).save!
end
