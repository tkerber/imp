require_relative 'node'
require_relative 'crypto'


module Imp
  
  # A tree consisting of Nodes.
  # 
  # All values are encrypted. This doesn't add additional security, but
  # prevents them from appearing in memory in plaintext if avoidable. Note
  # that any program designed specifically to tap into this programs memory
  # will not be hindered by this.
  class Tree
    
    include Enumerable
    
    def initialize(key, root = Node.new)
      @key = key
      @root = root
    end
    
    # Retrieves a node label following a forward-slash seperated list of
    # edge labels.
    # 
    # @param key [String] The forward-slash seperated list of edge labels.
    # @return [String] The decrypted value of the corresponding node label.
    def [](key)
      Crypto.decrypt(@key, @root.descendant(key).val)
    end
    
    # Sets a node label corresponding to a forward-slash seperated list of
    # edge labels.
    # 
    # @param key [String] The list of edge labels.
    # @param val [String] The value to set the node label to. This will be
    #   encrypted.
    def []=(key, val)
      @root.descendant(key, true).val = Crypto.encrypt(@key, val)
    end
    
    # Iterates over key/value pairs.
    # 
    # @param keys [Array<String>] A list of the keys followed to reach the
    #   current subtree.
    # @param subtree [Tree] The tree currently iterating over.
    # @yield [key, value] Key, value pairs where the key is a forward
    #   slash seperated string of edge labels. Values are not decrypted or
    #   processed.
    def each(keys = [], subtree = @root, &block)
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
      node = key.reduce(@root, :[])
      node.delete finalkey
    end
    
    # Removes any leaves with a nil value.
    def prune
      @root.prune
    end
    
    # Changes the encryption key.
    # 
    # @param key [String] The new encryption key.
    def key=(key)
      oldkey = @key
      @key = key
      each do |k, v|
        # Don't change nil values.
        next unless v
        # Otherwise decrypt the value with the old key and encypt it with the
        # new.
        self[k] = Crypto.decrypt(oldkey, v)
      end
    end
    
    # Delegates to the root node for string representation.
    # 
    # @return [String] The string representation of the tree.
    def to_s
      @root.to_s
    end
    
  end
  
end
