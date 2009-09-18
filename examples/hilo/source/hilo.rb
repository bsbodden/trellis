require 'rubygems'
require 'trellis'

include Trellis

module HiLo
  
  class HiLoGame < Application
    home :start
    logger.level = DEBUG
  end
  
  class Start < Page
    pages :guess
    
    def on_select
      @guess.initialize_target
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
    
    def initialize_target
      @target, @count, @message = rand(9) + 1, 0, ''
      self
    end
  end
  
  class GameOver < Page
    persistent :count
  end

  web_app = HiLoGame.new
  web_app.start 3001 if __FILE__ == $PROGRAM_NAME
end
