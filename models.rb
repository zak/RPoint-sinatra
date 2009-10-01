require 'rubygems' 
require 'datamapper'

class DateTime
  def rfc822
    self.strftime "%a, %d %b %Y %H:%M:%S %z"
  end
end

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3:///#{Dir.pwd}/../rpoint.db")

class Users
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
end

class Courses
  include DataMapper::Resource
  
  property :id, Serial
  property :author_id, Integer
  property :title, String, :length => 0..255
  property :permalink, String, :length => 0..225
  property :teaser, Text
  property :description, Text
  property :created_at, DateTime
  property :updated_at, DateTime
end

class Lectures
  include DataMapper::Resource
  
  property :id, Serial
  property :number, Integer 
  property :subjest, String, :length => 0..255
  property :course_id, Integer
  property :content, Text
  property :fieldwork, Text
  property :created_at, DateTime
  property :updated_at, DateTime
end

class Theses
  include DataMapper::Resource
  
  property :id, Serial
  property :lecture_id, Integer
  property :content, Text
  property :appraisal, String, :lenght => 0..255
end

class Fieldworks
  include DataMapper::Resource
  
  property :id, Serial
  property :lecture_id, Integer
  property :pupil_id, Integer
  property :description, Text
end

class Appraisals
  include DataMapper::Resource
  
  property :id, Serial
  property :mark, String, :lenght => 0..255
  property :thesis_id, Integer
  property :fieldwork_id, Integer
end

def install
  DataMapper.auto_migrate!
  
  Users.new(:login => 'admin', :password => '123456').save!
end
