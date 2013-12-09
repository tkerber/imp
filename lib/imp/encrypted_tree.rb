require_relative 'encrypted_file'
require_relative 'tree'

module Imp
  
  # A small wrapper for encrypted trees, to handle previous save versions
  # and passing on the key.
  class EncryptedTree < EncryptedFile
    
    # The tree.
    attr_reader :tree
    
    # Initializes the encrypted tree. Deals with deprecated serializations.
    # 
    # @param passwd [String] The password to the file.
    # @param file [String] The path to the file.
    def initialize(passwd, file)
      # Why this uglyness?
      # 
      # Previously, The class Node was called Tree, which means that any
      # saved files would be serialized with Imp::Tree instead of Imp::Node.
      # 
      # To allow for a smooth transition, any occurences of Imp::Tree are
      # replaced with Imp::Node.
      # 
      # Technically it is of course possible that the plaintext string
      # "Imp::Tree" appears somewhere else by accident, in practice the
      # chance of this is too remote to require special handling.
      super(passwd, file, false)
      @marshal = true
      if @cont == nil
        @cont = Node.new
      else
        if @cont.include? 'Imp::Tree'
          @cont.gsub!('Imp::Tree', 'Imp::Node')
        end
        @cont = Marshal.load(@cont)
      end
      @tree = Tree.new(@key, @cont)
    end
    
    # Sets a new password for the file.
    # 
    # @param passwd [String] The new password to use.
    def password=(passwd)
      # Super call
      EncryptedFile.instance_method(:password=).bind(self).call(passwd)
      # Pass the new key to the tree.
      @tree.key = @key
    end
    
  end
  
end
