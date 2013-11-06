require 'highline/import'
require 'readline'
require 'clipboard'

require_relative 'tree'

module PasswdManage
  
  VERSION = "0.1.0"
  
  module UI
    
    DEFAULT_FILE = '~/.passwd_manage/default.enc'
    PROMPT = '> '
    
    # Loads and decrypts a file. The password is asked for interactively.
    # 
    # @param file [String] The file to load from.
    def self.load_file(file = DEFAULT_FILE)
      $file = file
      until $tree
        begin
          passwd = ask("Password for file #{$file} (leave blank to cancel): ")\
              do |q|
            q.echo = false
          end
          if passwd == ''
            break
          end
          $tree = EncryptedTree.new(passwd, $file)
        rescue OpenSSL::Cipher::CipherError
          puts "Decryption failed. Corrupt file or wrong password."
        end
      end
    end
    
    # Closes the tree. This generally only happens right before ruby is about
    # to exit so it isn't that important but hey.
    def self.close_file
      $tree.close
      $tree = nil
    end
    
    # Runs the program.
    def self.main
      # TODO: config, by argv and possibly by config file.
      load_file
      # If no password was entered, quit.
      exit unless $tree
      welcome
      begin
        prompt
      ensure
        close_file
      end
    end
    
    # Deletes a key. If the key has no children, it is removed from the tree.
    # If it has children, it is removed from the tree if and only if it's
    # value was previously nil. Otherwise it's value is set to nil.
    # 
    # @param key [String] The key to delete.
    def self.del(key)
      return unless agree "Are you sure you want to delete the key #{key}? "
      node = $tree.cont.descendant(key)
      if node == nil
        puts "Key does not exist."
        return
      end
      unless node.leaf? || node.val == nil
        node.val = nil
        return
      end
      # The node must be deleted. Further, if any parent nodes would turn into
      # nil-leaves in the process, they too should be removed.
      
      # Splits into two at the *last* slash.
      parent_split = ->(str) do
        str.reverse.split('/', 2).map(&:reverse).reverse
      end
      key, conn = parent_split.(key)
      node = $tree.cont.descendant(key)
      node.delete conn
      while conn && node.leaf? && node.val == nil
        key, conn = parent_split.(key)
        node = $tree.cont.descendant(key)
        node.delete conn
      end
      $tree.flush
    end
    
    # Prints help text.
    def self.help
      puts (
        "help\t\t - Prints this help text\n"\
        "set KEY\t\t - Sets the value of the key to a value entered by the "\
          "user.\n"\
        "print\t\t - Prins a representation of the tree, without values.\n"\
        "print KEY\t - Prints the value of the key.\n"\
        "copy KEY\t - Copies the value of the key.\n"\
        "copyc INT KEY\t - Copies the (1-indexed) character from the value "\
          "of the key.\n"\
        "copy_junk\t - Erases the system clipboard.\n"\
        "del KEY\t\t - Deletes the key from the tree. If it has subtrees, "\
          "the subtrees get deleted if and only if the key had no value.\n"\
        "exit\t\t - Exit.\n\n"\
        "Keys are sorted in forward-slash seperated tree structure. "\
        "(slightly remenicient of urls).")
    end
    
    # Prints a value
    # 
    # @param key [String] The key for which to retrieve a value.
    def self.print_val(key)
      begin
        tmp_print $tree[key]
      # No method error arises from trying to work on a nil tree (or trying to
      # decrypt a nil value).
      rescue NoMethodError
        puts "No value entered for key '#{key}'"
      end
    end
    
    # Prints the currently loaded tree (without values).
    def self.print_tree
      puts $tree
    end
    
    # Set a value. Require entering the value to set it to twice until they
    # match. An empty value will cancel setting.
    # 
    # @param key [String] The key to set the value for.
    def self.set(key)
      first_pass = true
      pass1 = pass2 = nil
      until pass1 == pass2 && !first_pass
        unless first_pass
          puts "The values did not match. Please try again."
        end
        pass1 = ask "Please enter the value (leave blank to cancel): " do |q|
          q.echo = false
        end
        return if pass1 == ''
        pass2 = ask "Re-enter the value to confirm: " do |q|
          q.echo = false
        end
        first_pass = false
      end
      $tree[key] = pass1
      # We save the tree whenever it is modified.
      $tree.flush
    end
    
    # Clears the system clipboard.
    def self.copy_junk
      Clipboard.clear
    end
    
    # Copys the value of a key onto the system clipboard
    # 
    # @param key [String] The key of the value to copy.
    def self.copy(key)
      begin
        Clipboard.copy($tree[key])
      # No method error arises from trying to work on a nil tree (or trying to
      # decrypt a nil value).
      rescue NoMethodError
        puts "No value entered for key '#{key}'"
      end
    end
    
    # Copies the value of a single 1-indexed character of the value of a key
    # to the system clipboard.
    # 
    # @param argstr [String] The index to copy followed by the key, seperated
    #   by whitespace.
    def self.copyc_raw(argstr)
      pos, key = argstr.split(2)
      pos = pos.to_i
      copyc(char, key)
    end
    
    # Copies the value of a single 1-indexed character of the value of a key
    # to the system clipboard.
    # 
    # @param pos [Int] The index to copy. IMPORTANT: The string starts at
    #   index 1!
    # @param key [String] The key of the value to copy.
    def self.copyc(pos, key)
      begin
        Clipboard.copy($tree[key][pos - 1])
      # No method error arises from trying to work on a nil tree (or trying to
      # decrypt a nil value).
      rescue NoMethodError
        puts "No value entered for key '#{key}'"
      end
    end
    
    private
    
    # Prints strings, waits for enter then replaces them. Also adds color
    # for fancyness.
    def self.tmp_print(str)
      HighLine::SystemExtensions.raw_no_echo_mode
      print HighLine.color(str, :bold, :green)
      HighLine::SystemExtensions.get_character
      HighLine::SystemExtensions.restore_mode
      hidden_text = "\r<hidden>" << ' ' * (str.length - 8)
      puts HighLine.color(hidden_text, :bold, :green)
    end
    
    # Displays welcome text.
    def self.welcome
      puts "passwd_manage version #{VERSION}"
      puts "Using password file #{$file}."
      puts "Welcome to passwd_manage! Type 'help' for a list of commands."
    end
    
    # Runs a single command by the user. Also catches most errors and prints
    # them.
    def self.run(command)
      # Ctrl-D will return nil; this should be a quit signal.
      return :quit unless command
      # Ignore empty commands
      return if command == ''
      command, args = command.split(nil, 2)
      begin
        # TODO implement all of these.
        case command.downcase
        when 'help'
          help
        when 'set'
          set args
        when 'print'
          if args
            print_val args
          else
            print_tree
          end
        when 'copy'
          copy args
        when 'copyc'
          copyc_raw args
        when 'del'
          del args
        when 'copy_junk'
          copy_junk
        when 'exit'
          return :quit
        else
          puts "Command '#{command}' undefined. Type 'help' for a list of "\
            "commands."
        end
      rescue
        puts $!
      end
    end
    
    # Runs a basic prompt for the user to interface with the program.
    def self.prompt
      prompt_hist = []
      quit = false
      until quit
        input = Readline.readline(PROMPT, true)
        quit = run(input) == :quit
      end
    end
    
  end
  
end

if __FILE__ == $0
  PasswdManage::UI.main
end
