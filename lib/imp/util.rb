
module Imp
  
  # Contains misc. utility methods.
  module Util
    
    # Creates as many directories as needed.
    # 
    # @param dir [String] The directory to create.
    def self.mkdirs(dir)
      return if Dir.exists? dir
      parent = File.dirname(dir)
      mkdirs(parent)
      Dir.mkdir(dir)
    end
    
  end
  
end
