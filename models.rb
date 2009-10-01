require 'rubygems' 
require 'datamapper'

class DateTime
  def rfc822
    self.strftime "%a, %d %b %Y %H:%M:%S %z"
  end
end

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3:///#{Dir.pwd}/../rpoint.db")

class User
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
  property :subjest, String, :length => 0..255
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
  
  User.new(:login => 'admin', :password => '123456').save!
  Course.new(:title => 'Тестовый', :permalink => 'test', :description => 'Не очень длинный текст, а хотелось больше!', :user_id => 1).save!
  Invite.new(:token => '123456789', :created_at => Time.now, :expires_at => (Time.now + 3600), :user_id => 1).save!
  Invite.new(:token => '123', :created_at => (Time.now - 3600), :expires_at => (Time.now), :user_id => 1).save!
end
