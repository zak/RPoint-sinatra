require 'digest/sha1'

class UserSystem
  class BasisUser
    def accessed?(event)
      !!self.permissions.first(:event => event)
    end
  end
  
  class Guest
  end
  
  def self.random_string(len)
   #generate a random password consisting of strings and digits
   chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
   newpass = ""
   1.upto(len) { |i| newpass << chars[rand(chars.size-1)] }
   return newpass
  end
 
  def self.encrypt(pass)
    Digest::SHA1.hexdigest(pass)
  end
   
end
