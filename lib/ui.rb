require 'highline/import'
require 'readline'

require_relative 'tree'

module PasswdManage
  
  VERSION = "0.0.0"
  
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
      welcome
      begin
        prompt
      ensure
        close_file
      end
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
        "del KEY\t\t - Deletes the key from the tree. If it has subtrees, "\
          "the subtrees get deleted if and only if the key had no value.\n"\
        "copy_junk\t - Erases the system clipboard.\n"\
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
    
    private
    
    # Prints strings, waits for enter then replaces them. Also adds color
    # for fancyness.
    def self.tmp_print(str)
      # TODO
      puts str
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
