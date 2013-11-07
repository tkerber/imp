require_relative 'crypto'

module PasswdManage
  
  # A directory-esque tree with labeled nodes and edges.
  class Tree
    
    include Enumerable
    
    
    # The value of the current node in the tree.
    attr_accessor :val
    
    # Creates a new Tree.
    # 
    # @param val [Object] The node label of the tree.
    def initialize(val = nil)
      @val = val
      @succ = {}
    end
    
    # Gets a subtree by the label of the edge leading to it.
    # 
    # @param key [String] The edge label.
    # @param create [Boolean] Whether or not the create a new Node if there
    #   is no edge with the label given.
    # @return [Tree, nil] The tree at the edge, or nil if it didn't exist
    #   annd create was false.
    def [](key, create = false)
      if create and not @succ.include? key
        @succ[key] = Tree.new
      else
        @succ[key]
      end
    end
    
    # Removes a subtree by the label of the edge leading to it.
    # 
    # @param key [String] The edge label.s
    def delete(key)
      @succ.delete key
    end
    
    # Checks if this is a leaf node.
    # 
    # @return [Boolean] Wheter or not the node is a leaf.
    def leaf?
      @succ.length == 0
    end
    
    # Iterates over (edge, node) pairs.
    # 
    # @yield [String, Tree] Edge, node pairs of connected nodes.
    def each(&block)
      @succ.each(&block)
    end
    
    # Checks if an edge is included.
    # 
    # @param item [String] The string to check.
    # @return [Boolean] Whether or not the string is an edge label going out
    #   from this node.
    def include? item
      @succ.include? item
    end
    
    # Gets a (more distant descendant of the current node.
    # 
    # @param key [String] A forward-slash seperated list of the edge labels to
    #   follow.
    # @param create [Boolean] Whether or not to create nodes if the edge
    #   labels aren't used yet.
    # @return [Tree, nil] The node connected through the edge labels, or nil
    #   if there is no such node and create was false.
    def descendant(key, create = false)
      if key.include? '/'
        key, keys = key.split('/', 2)
        child = self[key, create]
        if child
          child.descendant(keys, create)
        end
      else
        self[key, create]
      end
    end
    
    # Prints the skeleton of the tree. Node labels are NOT printed.
    # 
    # @param indent [Int] By how many stages to indent the tree.
    # @return [String] The skeleton of the tree.
    def to_s(indent = 0)
      s = ""
      each do |k, v|
        s += '  ' * (indent) + k + "/\n" + v.to_s(indent + 1)
      end
      return s
    end
    
  end
  
  
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
    
    # Delegates to the tree for string representation.
    # 
    # @return [String] The string representation of the tree.
    def to_s
      @cont.to_s
    end
    
  end
  
end
