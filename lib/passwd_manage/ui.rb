require 'highline/import'
require 'readline'
require 'clipboard'
require 'timeout'

require_relative 'tree'

# A small and simple password manager.
module PasswdManage
  
  # The current version.
  VERSION = "0.1.0"
  
  # Module handling user I/O.
  module UI
    
    # The default file to save encrypted passwords in.
    DEFAULT_FILE = '~/.passwd_manage/default.enc'
    # The string precending user input in the prompt.
    PROMPT = '> '
    # The time in seconds, after which the program exits if it recieves no
    # input from the user.
    TIMEOUT = 300
    
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
          $strerr.puts "Decryption failed. Corrupt file or wrong password."
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
    
    
    private
    
    
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
      exit unless command
      # Ignore empty commands
      return if command == ''
      command, args = command.strip.split(nil, 2)
      command.downcase!
      if Commands::METHODS.include? command
        begin
          Commands.send(command.to_sym, args)
        rescue
          $stderr.puts $!
        end
      else
        $stderr.puts "Command '#{command}' undefined. Type 'help' for a list "\
          "of commands."
      end
    end
    
    # Runs a basic prompt for the user to interface with the program.
    def self.prompt
      prompt_hist = []
      quit = false
      until quit
        timeout do
          input = Readline.readline(PROMPT, true)
          quit = run(input) == :quit
        end
      end
    end
    
    # Times out execution of a block and exits printing an appropriate message
    # if the block doesn't time out in time.
    # 
    # The name is due to a conflict with Timeout's own.
    def self.timeout(&block)
      begin
        Timeout::timeout(TIMEOUT, &block)
      rescue Timeout::Error
        $stderr.puts "\nUser input timeout. Closing..."
        exit
      end
    end
    
  end
  
  
  # Contains the methods for all commands issued by the user.
  # All commands are executed with Commands#send
  module Commands
    
    # The signals which should be sent to this module.
    METHODS = [
      "help",
      "set",
      "paste",
      "print",
      "copy",
      "copyc",
      "del",
      "exit"]
    
    # Deletes a key. If the key has no children, it is removed from the tree.
    # If it has children, it is removed from the tree if and only if it's
    # value was previously nil. Otherwise it's value is set to nil.
    # 
    # @param key [String] The key to delete.
    # @param force [Boolean] Doesn't require confirmation from the user if
    #   it is true.
    def self.del(key, force = false)
      unless force ||
          agree("Are you sure you want to delete the key '#{key}'? ")
        return
      end
      node = $tree.cont.descendant(key)
      fail "Key does not exist." if node == nil
      
      if node.val == nil
        $tree.delete key
      else
        node.val = nil
      end
      # Remove any nil-leaves. (This may remove key IF it is a leaf)
      $tree.prune
      # Write out the tree.
      $tree.flush
    end
    
    # Prints help text.
    # 
    # @param args [Array] Ignored.
    def self.help(*args)
      puts (
        "help\t\t - Prints this help text\n"\
        "set KEY\t\t - Sets the value of the key to a value entered by the "\
          "user.\n"\
        "paste KEY\t\t - Sets the value of the key from the system "\
          "clipboard.\n"\
        "print\t\t - Prins a representation of the tree, without values.\n"\
        "print KEY\t - Prints the value of the key.\n"\
        "copy KEY\t - Copies the value of the key.\n"\
        "copyc INT KEY\t - Copies the (1-indexed) character from the value "\
          "of the key.\n"\
        "del KEY\t\t - Deletes the key from the tree. If it has subtrees, "\
          "the subtrees get deleted\n\t\t   if and only if the key had no "\
          "value.\n"\
        "exit\t\t - Exit.\n\n"\
        "Keys are sorted in forward-slash seperated tree structure. "\
        "(slightly remenicient of urls).")
    end
    
    # Prints either the tree if no argument is provided, or prints the value
    # of a certain key.
    # 
    # @param key [String, nil] The key if provided, or nil to print the tree.
    def self.print(key = nil)
      if key
        print_val(key)
      else
        print_tree
      end
    end
    
    # Set a value. Require entering the value to set it to twice until they
    # match. An empty value will cancel setting.
    # 
    # @param key [String] The key to set the value for.
    def self.set(key)
      fail "Key must be supplied." unless key
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
    
    # Sets a value from the system clipboard.
    # Fails if the clipboard is empty.
    # 
    # @param key [String] The key to set.
    def self.paste(key)
      fail "Key must be supplied." unless key
      pass = Clipboard.paste
      fail "Clipboard empty, could not paste." if pass == ''
      $tree[key] = pass
      $tree.flush
    end
    
    # Copys the value of a key onto the system clipboard.
    #et
    # @param key [String] The key of the value to copy. If nil, clears the
    #   clipboard instead.
    def self.copy(key = nil)
      fail "Key must be supplied." unless key
      begin
        UI.timeout do
          Clipboard.copy($tree[key])
          $stdout.print "Copy copied. Press enter to wipe..."
          gets
        end
      # No method error arises from trying to work on a nil tree (or trying to
      # decrypt a nil value).
      rescue NoMethodError
        fail "No value entered for key '#{key}'"
      ensure
        Clipboard.clear
      end
    end
    
    # Copies the value of a single 1-indexed character of the value of a key
    # to the system clipboard.
    # 
    # @param argstr [String] The index to copy followed by the key, seperated
    #   by whitespace.
    def self.copyc(argstr)
      pos, key = argstr.split(2)
      pos = pos.to_i
      copyc_expanded(char, key)
    end
    
    # Quits.
    # 
    # @param args [Array] Ignored.
    def self.quit(*args)
      exit
    end
    
    # This private is purely symbolic as classmethods have to be explicitly
    # defined as private.
    private
    
    # Copies the value of a single 1-indexed character of the value of a key
    # to the system clipboard.
    # 
    # @param pos [Int] The index to copy. IMPORTANT: The string starts at
    #   index 1!
    # @param key [String] The key of the value to copy.
    def self.copyc_expanded(pos, key)
      begin
        UI.timeout do
          Clipboard.copy($tree[key][pos - 1])
        end
      # No method error arises from trying to work on a nil tree (or trying to
      # decrypt a nil value).
      rescue NoMethodError
        fail "No value entered for key '#{key}'"
      ensure
        Clipboard.clear
      end
    end
    private_class_method :copyc_expanded
    
    # Prints strings, waits for enter then replaces them. Also adds color
    # for fancyness.
    def self.tmp_print(str)
      HighLine::SystemExtensions.raw_no_echo_mode
      $stdout.print HighLine.color(str, :bold, :green)
      begin
        UI.timeout do
          HighLine::SystemExtensions.get_character
        end
      ensure
        HighLine::SystemExtensions.restore_mode
        hidden_text = "\r<hidden>" << ' ' * [str.length - 8, 0].max
        puts HighLine.color(hidden_text, :bold, :green)
      end
    end
    private_class_method :tmp_print
    
    # Prints a value
    # 
    # @param key [String] The key for which to retrieve a value.
    def self.print_val(key)
      begin
        tmp_print $tree[key]
      # No method error arises from trying to work on a nil tree (or trying to
      # decrypt a nil value).
      rescue NoMethodError
        fail "No value entered for key '#{key}'."
      end
    end
    private_class_method :print_val
    
    # Prints the currently loaded tree (without values).
    def self.print_tree
      puts $tree
    end
    private_class_method :print_tree
    
  end
end

if __FILE__ == $0
  PasswdManage::UI.main
end
