require 'highline/import'

require_relative 'tree'

module PasswdManage
  
  VERSION = 0.0.0
  
  module UI
    
    DEFAULT_FILE = '~/.passwd_manage/default.enc'
    PROMPT = '> '
    
    def self.load_file(file = DEFAULT_FILE)
      $file = file
      until $tree
        begin
          passwd = ask("Password for file #{$file} (leave blank to cancel): ")\
              do |q|
            q.echo = false
          end
          if passwd == ''
            break
          end
          $tree = EncryptedTree.new(passwd, $file)
        rescue OpenSSL::Cipher::CipherError
          puts "Decryption failed. Corrupt file or wrong password."
        end
      end
    end
    
    def self.close_file
      $file.close
      $file = nil
    end
    
    def self.welcome
      puts "passwd_manage version #{VERSION}"
      puts "Using password file #{$file}."
      puts "Welcome to passwd_manage! Type 'help' for a list of commands."
    end
    
    def self.prompt
      # TODO implement prompt.
    end
    
    def self.main(*argv)
      # TODO: config, by argv and possibly by config file.
      load_file
      welcome
      prompt
      close_file
    end
    
  end
  
end
