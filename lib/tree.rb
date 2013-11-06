require_relative 'crypto'

module PasswdManage
  
  class Tree
    
    include Enumerable
    
    attr_accessor :val
    
    def initialize(val = nil)
      @val = val
      @succ = {}
    end
    
    def [](key, create = false)
      if create and not @succ.include? key
        @succ[key] = Tree.new
      else
        @succ[key]
      end
    end
    
    def each
      @succ.each do |i|
        yield i
      end
    end
    
    # key is a /-seperated string of keys to use.
    def descendant(key, create = false)
      if key.include? '/'
        key, keys = key.split('/', 2)
        self[key, create].descendant(keys, create)
      else
        self[key, create]
      end
    end
    
    def to_s(key, indent = 0)
      s= ''
      s += Crypto.decrypt(key, val) if val
      s += "\n"
      each do |k, v|
        s += ' ' * (indent + 2) + k + ':' + v.to_s(key, indent + 2)
      end
      s
    end
    
  end
  
  
  class EncryptedTree < EncryptedFile
    
    def initialize(passwd, file)
      super(passwd, file)
      if @cont == nil
        @cont = Tree.new
      end
    end
    
    # All values are themselves encrypted with the key again. This doesn't
    # add additional security, but prevents them from appearing in memory in
    # plaintext if avoidable. Note that any program designed specifically
    # to tap into this programs memory will have no problem with this.
    def [](key)
      Crypto.decrypt(@key, @cont.descendant(key).val)
    end
    
    def []=(key, val)
      @cont.descendant(key, true).val = Crypto.encrypt(@key, val)
    end
    
    def to_s
      @cont.to_s(@key)
    end
    
  end
  
end
