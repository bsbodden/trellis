require 'rubygems'
require 'trellis'

include Trellis

module Filters
  
  class Filters < Application
    home :login
    persistent :user
    
    logger.level = DEBUG
    
    # hardcoded user name and password (yeah don't do this)
    USER_NAME = "admin"
    PASSWORD  = "itsasecret!"
    
    # helper methods
    def admin?
      @user
    end
    
    filter :authorized?, :around do |page, &block|
      page.application.admin? ? block.call : page.redirect("/not_authorized")
    end
    
    filter :capitalize, :after do |page|
      page.answer = "#{page.answer} is #{page.answer.reverse} backwards"
    end
    
    def user
      @user = false unless @user
      @user
    end
    
    layout :main, %[
      <html xml:lang="en" lang="en" xmlns:trellis="http://trellisframework.org/schema/trellis_1_0_0.xsd" xmlns="http://www.w3.org/1999/xhtml">
      <head>
      	<meta content="text/html; charset=utf-8" http-equiv="Content-Type" />
        <title>@{@page_name}@</title>
      </head>
      <body>
        <h1>Trellis Filters Demo</h1>
        <?rb if admin? ?>
           	<h2>Logged in as @{@application.user}@</h2>
        <?rb end ?>
        <ul>
         	<li><a href="/protected">Protected Simple Page</a></li>
         	<li><a href="/protected_with_get">Protected Page with get method</a></li>
         	<li><a href="/protected_event/events/knock_knock">Protected Page Trigger by event</a></li>
         	<?rb if admin? ?>
         	<li><a href="/login/events/logout">Logout</a></li>
         	<?rb else ?>
         	<li><a href="/login">Login</a></li>
         	<?rb end ?>
       	</ul>
        @!{@body}@
      </body>
      </html>
     ], :format => :eruby
  end
  
  class Login < Page
    route '/login'
  
    def on_submit_from_login
      if params[:login_name] == Filters::USER_NAME && params[:login_password] == Filters::PASSWORD
        @application.user = Filters::USER_NAME
        redirect "/protected"
      else
        self
      end
    end
    
    def on_logout
      @application.user = false
      self
    end
    
    template %[
      <trellis:form tid="login" method="post" class="camisa-login">
  	    <label for="name">Username:</label>
  	    <trellis:text_field tid="name" id="name" />
  	    <label for="password">Password:</label>
  	    <trellis:password tid="password" id="password" />
  	    <trellis:submit tid="add" value="Login">
      </trellis:form>   
    ], :format => :html, :layout => :main
  end
  
  class Protected < Page 
    apply_filter :authorized?, :to => :all
    
    template %[
      <h1>This page is protected by an around filter</h1>   
      <h2>Shhhhhh!</h2>
    ], :format => :html, :layout => :main
  end
  
  class ProtectedWithGet < Page 
    apply_filter :authorized?, :to => :all
    
    def get
      self
    end
    
    template %[
      <h1>This page is also protected by an around filter</h1>   
      <h2>Let's also keep it quiet!</h2>
    ], :format => :html, :layout => :main
  end
  
  class ProtectedEvent < Page
    persistent :answer 
    apply_filter :authorized?, :to => :on_knock_knock
    apply_filter :capitalize, :to => :on_knock_knock
     
    def initialize
      @answer = "blah"
    end
    
    def on_knock_knock
      @answer = "who's there?"
      self
    end

    template %[
      <h1>Only a few chosen can see this</h1>   
      <h2>@{@answer}@</h2>
    ], :format => :eruby, :layout => :main
  end
  
  class NotAuthorized < Page
    template %[
      <h1>You are not authorized to see the page</h1>   
      <h2>Move along stranger!</h2>
    ], :format => :html, :layout => :main
  end
  
  Filters.new.start if __FILE__ == $PROGRAM_NAME
end
