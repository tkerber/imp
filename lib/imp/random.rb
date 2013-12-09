require 'openssl'

require_relative 'util'

module Imp
  
  # Several methods for cryptographically strong randomness, utilized for
  # the generation of random passwords.
  module Random
    
    # A list of the lowercase alphabet
    LOWER_ALPH = ('a'..'z').to_a
    # A list of the uppercase alphabet
    UPPER_ALPH = ('A'..'Z').to_a
    # A list of numeric digits.
    DIGITS     = ('0'..'9').to_a
    # A list of symbols which exist on practically every keyboard.
    SYMBOLS    = '!"$%^&*()-_=+[]{}\'@#~;:/?.>,<\\|'.split ''
    
    # A cryptographically strong version of list#sample.
    # 
    # @param list [Array] The list to take the sample from.
    # @return [Object] A random element from this list which was passed.
    def self.strong_sample(list)
      return nil if list.empty?
      # As OpenSSL::Random only has a method to generate random bytes, the
      # following procedure is taken: We take 4 more bytes than would be
      # required to conver all cases of the list. This ensures that almost
      # any probabalistic bais is eliminated.
      bytes_required = Math.log(list.length, 256).ceil
      bytes_required += 4
      rand = strong_rand bytes_required
      len = list.length
      list.each_with_index do |item, i|
        return item if rand <= (i + 1).to_f / len.to_f
      end
      fail "Tried to choose a random item but couldn't find one for random "\
        "value #{rand}."
    end
    
    # Generates a random string.
    # 
    # @param length [Int] The length of the string to generate.
    #   Should not be negative.
    # @param selection_set [Array<String>] An array of characters to choose
    #   from to generate the random string.
    # @return [String] A random string of the given length containing only
    #   the specified characters.
    def self.generate(length, selection_set)
      s = ''
      length.times do
        s <<= strong_sample selection_set
      end
      return s
    end
    
    # Generates a random string from a string of accepted character sets.
    # 
    # @param length [Int] The length of the string to generate.
    # @param selection_str [String] The character sets to use in the random
    #   string. l standing for lower case, u standing for upper case, d
    #   standing for digits and s standing for symbols are allowed in any
    #   combination, Any other characters are ignored.
    # @return [String] The random string of the given length using the
    #   specified character sets.
    def self.generate_from_str(length, selection_str)
      selection_str = selection_str.downcase
      selection = []
      selection += LOWER_ALPH if selection_str.include? "l"
      selection += UPPER_ALPH if selection_str.include? 'u'
      selection += DIGITS     if selection_str.include? 'd'
      selection += SYMBOLS    if selection_str.include? 's'
      fail "No valid character sets selected!" if selection == []
      generate length, selection
    end
    
    # Generates a random float from a certain amount of random bytes.
    # 
    # Random bytes are gotton by OpenSSL::Random#random_bytes.
    # The float will be returned between 0 and 1.
    # 
    # @param bytes [Int] The number of bytes to use for the random generation
    # @return [Float] A random value between 0 and 1.
    def self.strong_rand(bytes = 8)
      rand = OpenSSL::Random.random_bytes bytes
      # Convert to integer.
      rand = rand.each_byte.reduce(0) do |acc, byte|
        acc <<= 8
        acc += byte
      end
      # Convert to float between 0 and 1
      max = 1 << (8 * bytes)
      rand = rand.to_f / max.to_f
    end
    
  end
  
end
