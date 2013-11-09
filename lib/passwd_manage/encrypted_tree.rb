require_relative 'tree'
require_relative 'encrypted_file'
require_relative 'crypto'


module PasswdManage
  
  # A tree loaded from an encrypted file.
  # 
  # All values are themselves encrypted with the key again. This doesn't
  # add additional security, but prevents them from appearing in memory in
  # plaintext if avoidable. Note that any program designed specifically
  # to tap into this programs memory will have no problem with this.
  class EncryptedTree < EncryptedFile
    
    include Enumerable
    
    
    # Creates a new tree / load an existing one from a file.
    # 
    # @param passwd [String] The password to decrypt the file. Discarded
    #   after this call (although the key is kept in memory)
    # @param file [String] The location of the file to decrypt. If this does
    #   not exist, a new tree is made.
    def initialize(passwd, file)
      super(passwd, file)
      if @cont == nil
        @cont = Tree.new
      end
    end
    
    # Retrieves a node label following a forward-slash seperated list of
    # edge labels.
    # 
    # @param key [String] The forward-slash seperated list of edge labels.
    # @return [String] The decrypted value of the corresponding node label.
    def [](key)
      Crypto.decrypt(@key, @cont.descendant(key).val)
    end
    
    # Sets a node label corresponding to a forward-slash seperated list of
    # edge labels.
    # 
    # @param key [String] The list of edge labels.
    # @param val [String] The value to set the node label to. This will be
    #   encrypted.
    def []=(key, val)
      @cont.descendant(key, true).val = Crypto.encrypt(@key, val)
    end
    
    # Iterates over key/value pairs.
    # 
    # @param keys [Array<String>] A list of the keys followed to reach the
    #   current subtree.
    # @param subtree [Tree] The tree currently iterating over.
    # @yield [String, String] Key, value pairs where the key is a forward
    #   slash seperated string of edge labels. Values are not decrypted or
    #   processed.
    def each(keys = [], subtree = @cont, &block)
      # Yield the subtree's value unless it is the root.
      yield [keys.join('/'), subtree.val] unless keys == []
      subtree.each do |key, tree|
        each(keys + [key], tree, &block)
      end
    end
    
    # Checks whether a tree contains a key.
    # 
    # @param item [String] The forward slash seperated string of edge labels.
    def include?(item)
      @cont.descendant(key) != nil
    end
    
    # Deletes a node corresponding to a forward-slash seperated list of edge
    # labels.
    # 
    # @param key [String] The list of edge labels. Must be a valid key.
    def delete(key)
      # We seperate the last key from the first keys.
      key = key.split('/')
      finalkey = key[-1]
      key = key[0...-1]
      
      # Instead of using descendant we reduce over the root. This also handels
      # the root being the parent node well.
      node = key.reduce(@cont, :[])
      node.delete finalkey
    end
    
    # Iteratively removes any leaves with a nil value.
    # Not terribly efficient but there is no need to be.
    def prune
      pruned = true
      while pruned
        pruned = false
        self.each do |key, value|
          if value == nil && @cont.descendant(key).leaf?
            delete(key)
            pruned = true
          end
        end
      end
    end
    
    # Sets a new password for the file.
    # 
    # @param [String] The new password to generate a key from.
    def password=(passwd)
      key = @key
      # Super call.
      EncryptedFile.instance_method(:password=).bind(self).call(passwd)
      # If the file is still being initialized, @cont may be nil. In this case
      # return.
      return unless @cont
      each do |k, v|
        # Don't change nil values.
        next unless v
        # Otherwise decrypt with the old key and encrypt with the new.
        # (Encryption is done automatically by #[]=)
        self[k] = Crypto.decrypt(key, v)
      end
    end
    
    # Delegates to the tree for string representation.
    # 
    # @return [String] The string representation of the tree.
    def to_s
      @cont.to_s
    end
    
  end
  
end
