require 'highline/import'

require 'readline'
require 'optparse'

require_relative 'encrypted_tree'
require_relative 'util'
require_relative 'commands'
require_relative '../imp'

# A small and simple password manager.
module Imp
  
  # Module handling user I/O.
  module UI
    
    # The default file to save encrypted passwords in.
    DEFAULT_FILE = '~/.imp/default.enc'
    # The file of the history of the prompt.
    HISTFILE = '~/.imp/hist'
    # The string precending user input in the prompt.
    PROMPT = 'imp> '
    
    # Loads and decrypts a file. The password is asked for interactively.
    def self.load_file
      until $tree
        begin
          passwd = get_passwd
          return unless passwd
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
      rescue Interrupt
        puts
        exit
      ensure
        close_file
      end
    end
    
    private
    
    
    # Load program options.
    def self.load_options
      $opts = {}
      OptionParser.new do |opts|
        opts.banner = "Usage: imp [options]"
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
      puts "imp version #{VERSION}"
      puts "Using password file '#{$file}'."
      puts "Welcome to imp! Type 'help' for a list of commands."
    end
    private_class_method :welcome
    
    # Runs a single command by the user. Also catches most errors and prints
    # them.
    # 
    # @param command [String] The command to run.
    # @return [:quit, nil] :quit to quit, nil to do nothing.
    def self.run(command)
      # Ctrl-D will return nil; this should be a quit signal.
      # As this is also the only input not send off with a new line, one
      # will be printed for consistency.
      unless command
        puts
        return :quit
      end
      # Ignore empty commands
      return if command == ''
      command, args = command.strip.split(nil, 2)
      command.downcase!
      if Commands::METHODS.include? command
        begin
          return Commands.send(command.to_sym, args)
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
          Util.timeout do
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
    
    # Gets the password for the encrypted file.
    # 
    # @return [nil, String] nil to signal no password was given, or the
    #   password itself.
    def self.get_passwd
      if File.exists? File.expand_path($file)
        pass = ask("Password for file '#{$file}' (leave blank to cancel): ")\
            do |q|
          q.echo = false
        end
        pass == "" ? nil : pass
      else
        puts "This is your first time using the file '#{$file}' to save "\
          "your passwords."
        puts "Please enter your password for first-time use."
        puts "Note that you can change this password at any time."
        Util.read_passwd("password for the file '#{$file}'")
      end
    end
    private_class_method :get_passwd
    
  end
  
end
