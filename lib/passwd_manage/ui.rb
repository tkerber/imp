require 'highline/import'
require 'readline'
require 'clipboard'
require 'timeout'
require 'optparse'

require_relative 'tree'
require_relative 'util'

# A small and simple password manager.
module PasswdManage
  
  # The current version.
  VERSION = "0.1.0"
  
  # Module handling user I/O.
  module UI
    
    # The default file to save encrypted passwords in.
    DEFAULT_FILE = '~/.passwd_manage/default.enc'
    # The file of the history of the prompt.
    HISTFILE = '~/.passwd_manage/hist'
    # The string precending user input in the prompt.
    PROMPT = '> '
    # The time in seconds, after which the program exits if it recieves no
    # input from the user.
    TIMEOUT = 300
    
    # Loads and decrypts a file. The password is asked for interactively.
    def self.load_file
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
          $stderr.puts "Decryption failed. Corrupt file or wrong password."
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
      load_options
      if $opts[:file]
        $file = $opts[:file]
      else
        $file = DEFAULT_FILE
      end
      load_file
      # If no password was entered, quit.
      exit unless $tree
      welcome
      init_readline
      begin
        prompt
      ensure
        close_file
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
    
    
    private
    
    
    # Load program options.
    def self.load_options
      $opts = {}
      OptionParser.new do |opts|
        opts.banner = "Usage: passwd_manage [options]"
        opts.on('-v', '--[no-]verbose', 'Print exception stacks.') do |v|
          $opts[:verbose] = v
        end
        opts.on('-f', '--file [FILE]', 'Load from the given file') do |f|
          $opts[:file] = f
        end
      end.parse!
    end
    private_class_method :load_options
    
    # Displays welcome text.
    def self.welcome
      puts "passwd_manage version #{VERSION}"
      puts "Using password file #{$file}."
      puts "Welcome to passwd_manage! Type 'help' for a list of commands."
    end
    private_class_method :welcome
    
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
          if $opts[:verbose]
            $!.backtrace.each do |t|
              puts "\tfrom #{t}"
            end
          end
        end
      else
        $stderr.puts "Command '#{command}' undefined. Type 'help' for a list "\
          "of commands."
      end
    end
    private_class_method :run
    
    # Runs a basic prompt for the user to interface with the program.
    def self.prompt
      load_prompt_hist
      quit = false
      begin
        until quit
          timeout do
            input = Readline.readline(PROMPT, true)
            quit = run(input) == :quit
          end
        end
      ensure
        save_prompt_hist
      end
    end
    private_class_method :prompt
    
    # Loads the prompt history.
    def self.load_prompt_hist
      f = File.expand_path(HISTFILE)
      return unless File.exists? f
      f = File.new f
      cont = f.read
      f.close
      Marshal.load(cont).each do |h|
        Readline::HISTORY << h
      end
    end
    private_class_method :load_prompt_hist
    
    # Saves the prompt history.
    def self.save_prompt_hist
      f = File.expand_path(HISTFILE)
      Util.mkdirs(File.dirname(f))
      f = File.new(f, "w")
      f.write(Marshal.dump(Readline::HISTORY.to_a))
      f.close
    end
    private_class_method :save_prompt_hist
    
    # Initializes autocompletion for readline.
    def self.init_readline
      Readline.completion_proc = proc do |s|
        reg = /^#{Regexp.escape s}/
        ret = Commands::METHODS.grep reg
        ret + $tree.find_all{ |k, v|  k =~ reg && v }.map{ |k, _|  k }
      end
    end
    private_class_method :init_readline
    
  end
  
  
  # Contains the methods for all commands issued by the user.
  # All commands are executed with Commands#send
  module Commands
    
    # The signals which should be sent to this module.
    METHODS = [
      "help",
      "set",
      "change_passwd",
      "paste",
      "print",
      "copy",
      "copy_raw",
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
      puts ("
help          - Prints this help text
set KEY       - Sets the value of the key to a value entered by the user.
change_passwd - Changes the password of the current file.
paste KEY     - Sets the value of the key from the system clipboard.
print         - Prints a representation of the tree, without values.
print KEY     - Prints the value of the key.
copy KEY      - Copies the value of the key, auto clears clipboard afterward.
copy_raw      - Clears the clipboard.
copy_raw KEY  - Copies the value of a key, without clearing the clipboard.
                Useful for moving values around between keys.
copyc INT KEY - Copies the (1-indexed) character from the value of the key.
del KEY       - Deletes the key from the tree. If it has subtrees, the
                subtrees get deleted if and only if the key had no value.
exit          - Exit.

Keys are sorted in forward-slash seperated tree structure (slightly
remenicient of urls).")
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
    
    # Changes the encryption password.
    # 
    # @param args [Array] Ignored.
    def self.change_passwd(*args)
      pass = read_passwd
      return unless pass
      $tree.password = pass
      $tree.flush
    end
    
    # Set a value. Require entering the value to set it to twice until they
    # match. An empty value will cancel setting.
    # 
    # @param key [String] The key to set the value for.
    def self.set(key)
      fail "Key must be supplied." unless key
      pass = read_passwd
      return unless pass
      $tree[key] = pass
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
    # 
    # @param key [String, nil] The key of the value to copy. If nil, clears
    #   the clipboard instead.
    def self.copy_raw(key = nil)
      begin
        if key
          Clipboard.copy($tree[key])
        else
          Clipboard.clear
        end
      # No method error arises from trying to work on a nil tree (or trying to
      # decrypt a nil value).
      rescue NoMethodError
        fail "No value entered for key '#{key}'."
      end
    end
    
    # Copys the value of a key onto the system clipboard. And auto-clears it
    # afterwards.
    # 
    # @param key [String] The key of the value to copy.
    def self.copy(key)
      fail "Key must be supplied." unless key
      begin
        UI.timeout do
          copy_raw key
          $stdout.print "Value copied. Press enter to wipe..."
          gets
        end
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
    
    # Reads a password from the user.
    # 
    # @return [String, nil] The password enetered, or nil if aborted.
    def self.read_passwd
      first_pass = true
      pass1 = pass2 = nil
      until pass1 == pass2 && !first_pass
        unless first_pass
          puts "The pass did not match. Please try again."
        end
        pass1 = ask "Please enter the pass (leave blank to cancel): " do |q|
          q.echo = false
        end
        return if pass1 == ''
        pass2 = ask "Re-enter the pass to confirm: " do |q|
          q.echo = false
        end
        first_pass = false
      end
      return pass1
    end
    private_class_method :read_passwd
    
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
        fail "No value entered for key '#{key}'."
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
