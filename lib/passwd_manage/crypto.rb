require 'openssl'

module PasswdManage
  
  # Contains methods for easily interfacing with ruby's encryption algorithms.
  # Uses 256 bit AES in CBC mode with keys generated by PBKDF2 using SHA1
  # and 10 000 iterations.
  module Crypto
    
    KEYLEN = 32
    BLOCK_SIZE = 16
    SALTLEN = KEYLEN
    ITER = 10_000
    MODE = :CBC
    
    # Delegates key generation to PBKDF2
    # 
    # @param passwd [String] The password.
    # @param salt [String] The salt.
    # @return [String] The key.
    def self.get_key(passwd, salt)
      OpenSSL::PKCS5.pbkdf2_hmac_sha1(passwd, salt, ITER, KEYLEN)
    end
    
    # Gets a random salt.
    # 
    # @return [String] A salt.
    def self.rand_salt
      OpenSSL::Random.random_bytes SALTLEN
    end
    
    # Encrypts a string. The result is the IV, followed by the actual
    # encrypted string.
    # 
    # @param key [String] The key.
    # @param data [String] The unencrypted data.
    # @return [String] The encrypted data.
    def self.encrypt(key, data)
      cipher = OpenSSL::Cipher::AES.new(KEYLEN * 8, MODE)
      cipher.encrypt
      iv = cipher.random_iv
      cipher.key = key
      
      iv + cipher.update(data) + cipher.final
    end
    
    # Decrypts a string encrypted by ::encrypt
    # 
    # @param key [String] The key.
    # @param data [String] The encrypted data.
    # @return [String] The unencrypted data.
    def self.decrypt(key, data)
      cipher = OpenSSL::Cipher::AES.new(KEYLEN * 8, MODE)
      cipher.decrypt
      cipher.iv = data[0...BLOCK_SIZE]
      cipher.key = key
      
      cipher.update(data[BLOCK_SIZE..-1]) + cipher.final
    end
    
  end
  
  
  # A rudimentary wrapper to interface with encrypted files.
  # 
  # Files are saved as a concatination of the password's salt and a string
  # encrypted with Crypto#encrypt. The string may be marshalled content, or
  # it may be the content itself.
  # 
  # @note This is NOT a file object. The file's content is loaded entirely
  #   into memory.
  class EncryptedFile
    
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
      f.print(@salt)
      if @marshal
        cont = Marshal.dump @cont
      else
        cont = @cont
      end
      f.print(Crypto.encrypt(@key, cont))
      f.flush
      f.close
    end
    
    # Nulls the key. (It may still be in memory!)
    def close
      @cont = nil
      @key  = nil
    end
    
    private
    
    # Loads the content from the file.
    # 
    # @param passwd [String] The password.
    def init_with_file(passwd)
      f = File.new(@file)
      @cont = f.read
      f.close
      @salt = @cont[0...Crypto::SALTLEN]
      @cont = @cont[Crypto::SALTLEN..-1]
      @key = Crypto.get_key(passwd, @salt)
      @cont = Crypto.decrypt(@key, @cont)
      @cont = Marshal.load(@cont) if @marshal
    end
    
    # Initializes the encrypted file.
    # 
    # @param passwd [String] The password.
    def first_time_init(passwd)
      mkdirs(File.dirname(@file))
      @salt = Crypto.rand_salt
      @key = Crypto.get_key(passwd, @salt)
      @cont = nil
    end
    
    # Creates as many directories as needed.
    # 
    # @param dir [String] The directory to create.
    def mkdirs(dir)
      return if Dir.exists? dir
      parent = File.dirname(dir)
      mkdirs(parent)
      Dir.mkdir(dir)
    end
    
  end
  
end