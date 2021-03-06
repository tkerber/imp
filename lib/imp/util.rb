require 'highline/import'

require 'timeout'

module Imp
  
  # Contains misc. utility methods.
  module Util
    
    # The time in seconds, after which the program exits if it recieves no
    # input from the user.
    TIMEOUT = 300
    
    # Creates as many directories as needed.
    # 
    # @param dir [String] The directory to create.
    def self.mkdirs(dir)
      return if Dir.exists? dir
      parent = File.dirname(dir)
      mkdirs(parent)
      Dir.mkdir(dir)
    end
    
    # Reads a password from the user.
    # 
    # @param desc [String] The description of the password inserted into query
    #   texts.
    # @return [String, nil] The password enetered, or nil if aborted.
    def self.read_passwd(desc = 'password')
      first_pass = true
      pass1 = pass2 = nil
      until pass1 == pass2 && !first_pass
        unless first_pass
          puts "The pass did not match. Please try again."
        end
        pass1 = ask "Please enter the #{desc} (leave blank to cancel): " do |q|
          q.echo = false
        end
        return if pass1 == ''
        pass2 = ask "Re-enter the #{desc} to confirm: " do |q|
          q.echo = false
        end
        first_pass = false
      end
      return pass1
    end
    
    # Times out execution of a block and exits printing an appropriate message
    # if the block doesn't time out in time.
    def self.timeout(&block)
      begin
        Timeout::timeout(TIMEOUT, &block)
      rescue Timeout::Error
        $stderr.puts "\nUser input timeout. Closing..."
        exit
      end
    end
    
  end
  
end
