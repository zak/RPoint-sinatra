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
  property :password, String, :length => 0..255
end



def install
  DataMapper.auto_migrate!
  
  Users.new(:login => 'admin', :password => '123456').save!
end
