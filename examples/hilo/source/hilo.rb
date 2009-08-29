require 'rubygems'
require 'trellis'

include Trellis

module HiLo
  
  class HiLoGame < Application
    home :start
    pages :guess, :game_over
  end
  
  class Start < Page
    pages :guess
    
    def on_select
      @guess.target = rand(10);
      return @guess
    end
  end
  
  class Guess < Page
    pages :game_over
    persistent :target, :message, :count
    
    def on_select_from_link(value)
      guess_val = value.to_i
      next_page = self
      @count = @count + 1
      if guess_val == @target 
        @game_over.count = @count
        next_page = @game_over
      else 
        @message = "Guess #{guess_val} is too #{guess_val < @target ? 'low' : 'high'}"  
      end
      
      next_page
    end
    
    def target=(value)
      @target, @count, @message = value, 0, ''
    end
  end
  
  class GameOver < Page
    attr_accessor :count
  end

  web_app = HiLoGame.new
  web_app.start 3001 if __FILE__ == $PROGRAM_NAME
end
