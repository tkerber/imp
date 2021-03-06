require 'highline/import'

require 'clipboard'

require_relative 'util'
require_relative 'random'

module Imp
  
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
      "exit",
      "gen"]
    
    # Deletes a key. If the key has no children, it is removed from the tree.
    # If it has children, it is removed from the tree if and only if it's
    # value was previously nil. Otherwise it's value is set to nil.
    # 
    # @param key [String] The key to delete.
    # @param force [Boolean] Doesn't require confirmation from the user if
    #   it is true.
    def self.del(key, force = false)
      fail "Key must be supplied." unless key
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
      $treefile.flush
    end
    
    # Prints help text.
    # 
    # @param args [Array] Ignored.
    def self.help(*args)
      puts ("
change_passwd - Changes the password of the current file.
copy KEY      - Copies the value of the key, auto clears clipboard afterward.
copyc INT KEY - Copies the (1-indexed) character from the value of the key.
copy_raw      - Clears the clipboard.
copy_raw KEY  - Copies the value of a key, without clearing the clipboard.
                Useful for moving values around between keys.
del KEY       - Deletes the key from the tree. If it has subtrees, the
                subtrees get deleted if and only if the key had no value.
exit          - Exit.
gen KEY       - Generates a random password and places it under the key
                given.
help          - Prints this help text
paste KEY     - Sets the value of the key from the system clipboard.
print         - Prints a representation of the tree, without values.
print KEY     - Prints the value of the key.
set KEY       - Sets the value of the key to a value entered by the user.

Keys are sorted in forward-slash seperated tree structure (slightly
remenicient of urls). E.g. in a tree structure like

some/
  long/
    path
  other/
    path

'some/long/path' would be a valid key.

Nodes can also have values, so path 'some/long/path' and 'some/long' can both
have values assigned to them.

Nodes are automatically created and destroyed as needed.")
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
      pass = Util.read_passwd("password for file '#{$file}'")
      return unless pass
      $treefile.password = pass
      $treefile.flush
    end
    
    # Set a value. Require entering the value to set it to twice until they
    # match. An empty value will cancel setting.
    # 
    # @param key [String] The key to set the value for.
    def self.set(key)
      fail "Key must be supplied." unless key
      pass = Util.read_passwd
      return unless pass
      $tree[key] = pass
      # We save the tree whenever it is modified.
      $treefile.flush
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
      $treefile.flush
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
        Util.timeout do
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
      pos, key = argstr.split(nil, 2)
      pos = pos.to_i
      copyc_expanded(pos, key)
    end
    
    # Quits.
    # 
    # @param args [Array] Ignored.
    def self.exit(*args)
      :quit
    end
    
    # Generate a random password, placing it under the given key.
    # 
    # @param key [String] The key to generate the password for.
    def self.gen(key)
      fail "Key must be supplied." unless key
      len = ask("How Many digits should the password have? Leave blank or "\
        "<= 0 to cancel): ").to_i
      return if len <= 0
      type = ask("What type of password would you like to generate?\nEnter "\
        "a combination of the digits 'l' for lowercase, 'u' for uppercase, "\
        "'d' for digits and 's' for symbols\nto indicate which should be "\
        "included in your password: ")
      pass = Imp::Random.generate_from_str len, type
      $tree[key] = pass
      # We save the tree whenever it is modified.
      $treefile.flush
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
        Util.timeout do
          Clipboard.copy($tree[key][pos - 1])
          $stdout.print "Character copied. Press enter to wipe..."
          gets
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
    # 
    # @param str [String] The string to print temporarily.
    def self.tmp_print(str)
      HighLine::SystemExtensions.raw_no_echo_mode
      $stdout.print HighLine.color(str, :bold, :green)
      begin
        Util.timeout do
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
