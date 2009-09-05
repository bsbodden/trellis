require 'rubygems'
require 'trellis'

include Trellis

module ObjectEditor
  
  class Address
    attr_accessor :aid, :first_name, :last_name, :street_1, :street_2, :city, :state, :zip, :email, :phone
    
    def initialize(aid, first_name, last_name, street_1, street_2, city, state, zip, email, phone)
      @aid, @first_name, @last_name, @street_1, @street_2, @city, @state, @zip, @email, @phone = aid, first_name, last_name, street_1, street_2, city, state, zip, email, phone
      @@_addresses ||= {}
      @@_addresses[self.aid] = self
    end
    
    def self.addresses
      @@_addresses
    end
    
    def to_s
      "#{@aid}: #{@first_name} #{@last_name}"
    end
    
    Address.new(1, "Richard", "Jeni", "10544 E Meadowhill Dr.", "", "Scottsdale", "AZ", "85255", "rjenni@platypus.com", "555-2715777")
    Address.new(2, "Mitch", "Hedberg", "123 Broadway", "", "New York", "NY", "20231", "mitch@hedberg.com", "555-5551234")
    Address.new(3, "Sam", "Kenison", "125 Fifth Ave.", "", "New York", "NY", "20123", "sam@kenison.com", "555-5558675")
    Address.new(4, "Richard", "Prior", "321 Unfunny Street", "", "New York", "NY", "20202", "richard@prior.com", "555-2675877")
    Address.new(5, "George", "Carlin", "999 Union Street", "", "New York", "NY", "20231", "george@carlin.com", "555-5592734")
    Address.new(6, "Bill", "Hicks", "125 Fifth Ave.", "", "New York", "NY", "20786", "bill@hicks.com", "555-5556775")
    Address.new(7, "Rodney", "Dangerfield", "13884 E. Kalil Dr.", "", "Scottsdale", "AZ", "85259", "rodney@dangerfield.com", "555-2715777")
    Address.new(8, "Andy", "Kauffman", "789 Main Street", "", "New York", "NY", "20231", "andy@kauffman.com", "555-5534634")
    Address.new(9, "Lenny", "Bruce", "456 Sixth Ave.", "", "New York", "NY", "45637", "lenny@bruce.com", "555-5837475")
    Address.new(10, "Redd", "Foxx", "314 Rebel Force Dr.", "", "New Albany", "NY", "20212", "redd@foxx.com", "555-5557475")   
  end
  
  class CrudComponentsExample < Application
    home :addresses
    
    map_static ['/images', '/style', '/favicon.ico']
  end
  
  class Addresses < Page
    pages :address_view_edit
    
    def before_load
      @grid_addresses.columns(:first_name, :last_name, :street_1, :city, :state, :zip, :email, :phone)
      @grid_addresses.sort_by :all
      @grid_addresses.add_command(:name => "edit", :context => "aid", :image => "/images/edit.gif")
      @all_addresses = Address.addresses.values
    end
    
    def on_edit_from_addresses id
      @address_view_edit.object_editor_address.model = Address.addresses[id.to_i]
      @address_view_edit
    end
    
  end
  
  class AddressViewEdit < Page
    
    pages :addresses
       
    def before_load
      @object_editor_address.fields(:first_name, :last_name, :street_1, :city, :state, :zip, :email, :phone)
      @object_editor_address.submit_text = (@model && @model.aid ? "Save" : "Create")
      @object_editor_address.on_submit { |model|
        logger.info "saving the object #{model.to_s}, responding to an event in #{self}"
        @addresses #navigate back to the addresses page
      }
    end 
  end

  web_app = CrudComponentsExample.new
  web_app.start 3019 if __FILE__ == $PROGRAM_NAME
end
