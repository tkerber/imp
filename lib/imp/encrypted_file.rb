require_relative 'crypto'
require_relative 'util'

module Imp
  
  # A rudimentary wrapper to interface with encrypted files.
  # 
  # Files are saved as a concatination of the password's salt and a string
  # encrypted with Crypto#encrypt. The string may be marshalled content, or
  # it may be the content itself.
  # 
  # @note This is NOT a file object. The file's content is loaded entirely
  #   into memory.
  class EncryptedFile
    
    # The plaintext content of the encrypted file.
    attr_accessor :cont
    
    # If the file exists, load the content from it. Otherwise load the
    # content as nil, generate a salt and key to prepare for writing.
    # 
    # @param passwd [String] The password.
    # @param file [String] The location of the file.
    # @param marshal [Boolean] Whether or not the content is marshalled.
    def initialize(passwd, file, marshal = true)
      @file = File.expand_path(file)
      @marshal = marshal
      if File.exists? @file
        init_with_file(passwd)
      else
        first_time_init(passwd)
      end
    end
    
    # Writes the content to the file.
    def flush
      f = File.new(@file, "w")
      f << @salt
      if @marshal
        cont = Marshal.dump @cont
      else
        cont = @cont
      end
      f << Crypto.encrypt(@key, cont)
      f.flush
      # Encrypted files should only be readable by their owner. Doesn't really
      # add much security but hey.
      f.chmod(0600)
      f.close
    end
    
    # Nulls the key. (It may still be in memory!)
    def close
      @cont = nil
      @key  = nil
    end
    
    private
    
    def password=(passwd)
      @salt = Crypto.rand_salt
      @key = Crypto.get_key(passwd, @salt)
    end
    
    # Loads the content from the file.
    # 
    # @param passwd [String] The password.
    def init_with_file(passwd)
      f = File.new(@file)
      @cont = f.read
      f.close
      @salt = @cont.byteslice 0...Crypto::SALTLEN
      @cont = @cont.byteslice Crypto::SALTLEN..-1
      @key = Crypto.get_key(passwd, @salt)
      @cont = Crypto.decrypt(@key, @cont)
      @cont = Marshal.load(@cont) if @marshal
    end
    
    # Initializes the encrypted file.
    # 
    # @param passwd [String] The password.
    def first_time_init(passwd)
      Util.mkdirs(File.dirname(@file))
      self.password = passwd
      @cont = nil
    end
    
  end
  
end
