require 'rubygems'
require 'trellis'

include Trellis

module Hangman
  class HangmanGame < Application
    home :start
    
    map_static ['/images', '/style', '/favicon.ico']
  end
  
  class Start < Page
    pages :guess

    @@words = Array.new
    File.open("#{File.dirname($0)}/../html/resources/word_list.txt", "r").each do |word|
      @@words << word.strip
    end    
    
    def on_select
      @guess.set_target_word = @@words[rand(@@words.size)]
      @guess
    end
  end
  
  class Guess < Page
    pages :game_over
    persistent :target, :guesses_left, :letters, :guessed, :win

    def on_select_from_link(value)
      next_page = self
      @guessed[value] = true
      
      if @target.include?(value)
        @letters.each_index { |index| @letters[index] = value if @target[index] == value }
      else
        @guesses_left = @guesses_left - 1
      end
      
      @win = !@letters.include?('_')
      
      if @win || @guesses_left == 0
        next_page = @game_over
        @game_over.target = @target
        @game_over.win = @win
        @game_over.guesses_left = @guesses_left       
      end
      
      next_page
    end
    
    def set_target_word=(value)
      @win = false
      @guesses_left = 5
      @target = Array.new
      value.scan(/.{1}/).each { |char| @target << char }
      @letters = Array.new(@target.length, '_')
      @guessed = Hash.new(false)
      ('a'..'z').each { |letter| @guessed[letter] = false }
    end
  end
  
  class GameOver < Page
    persistent :target, :win, :guesses_left
  end
  
  web_app = HangmanGame.new
  web_app.start 3010 if __FILE__ == $PROGRAM_NAME 
end
