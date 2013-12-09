
module Imp
  
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
    # @yield [edge, node] Edge, node pairs of connected nodes.
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
        s += '  ' * indent
        s += k
        s += '/' unless v.leaf?
        s += '*' if v.val
        s += "\n"
        s += v.to_s(indent + 1)
      end
      return s
    end
    
  end
  
end
