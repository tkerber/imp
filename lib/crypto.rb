require 'openssl'

# Contains:
# 
# module Crypto
#   Convenience methods for AES encryption used in this program.
# class EncryptedFile
#   NOT a file object; reads and decrypts the entire file to #cont. Encrypts
#   and decrypts marshalled objects (or plain strings) with a password.
module PasswdManage
  
  module Crypto
    
    # Convenience methods for 256-bit CBC AES encryption, with keys generated
    # with SHA1-based PDKDF2.
    
    KEYLEN = 32
    BLOCK_SIZE = 16
    SALTLEN = KEYLEN
    ITER = 10000
    MODE = :CBC
    
    def self.get_key(passwd, salt)
      OpenSSL::PKCS5.pbkdf2_hmac_sha1(passwd, salt, ITER, KEYLEN)
    end
    
    def self.rand_salt
      OpenSSL::Random.random_bytes SALTLEN
    end
    
    # Result is an IV, followed by the encrypted string.
    def self.encrypt(key, data)
      cipher = OpenSSL::Cipher::AES.new(KEYLEN * 8, MODE)
      cipher.encrypt
      iv = cipher.random_iv
      cipher.key = key
      
      iv + cipher.update(data) + cipher.final
    end
    
    def self.decrypt(key, data)
      cipher = OpenSSL::Cipher::AES.new(KEYLEN * 8, MODE)
      cipher.decrypt
      cipher.iv = data[0...BLOCK_SIZE]
      cipher.key = key
      
      cipher.update(data[BLOCK_SIZE..-1]) + cipher.final
    end
    
  end
  
  
  class EncryptedFile
    
    attr_accessor :cont
    
    # An encrypted file is a salt, followed by a string encrypted by Crypto.
    # The string may be the marshalled content, or it may be the content
    # itself.
    def initialize(passwd, file, marshal = true)
      @file = File.expand_path(file)
      @marshal = marshal
      if File.exists? @file
        init_with_file(passwd)
      else
        first_time_init(passwd)
      end
    end
    
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
    
    def first_time_init(passwd)
      mkdirs(File.dirname(@file))
      @salt = Crypto.rand_salt
      @key = Crypto.get_key(passwd, @salt)
      @cont = nil
    end
    
    def mkdirs(dir)
      return if Dir.exists? dir
      parent = File.dirname(dir)
      mkdirs(parent)
      Dir.mkdir(dir)
    end
    
  end
  
end
