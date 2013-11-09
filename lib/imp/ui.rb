require 'highline/import'
require 'readline'
require 'timeout'
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
      puts "Using password file #{$file}."
      puts "Welcome to imp! Type 'help' for a list of commands."
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
  
end
